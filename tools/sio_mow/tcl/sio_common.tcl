set script_dir [file dirname [info script]]

proc open_file {fname {mode r}} {
  set nmode [string tolower [string index $mode 0]]
  set is_gz [regexp -- {\.gz$} $fname]
  if {$nmode eq "r" || $nmode eq ""} {
    if {$is_gz} { set fname "| gzcat $fname" }
    set fp [open $fname $mode]
  } elseif {$nmode eq "w"} {
    if {$is_gz} { set fname "| gzip -9f > $fname" }
    set fp [open $fname $mode]
  } else {
    error "Invalid [lindex [info level 0] 0] mode $mode"
  }
  return $fp
}

proc run_check_port_location_outside_bbox_fis_fos {outfile {td_location_file ""}} {
  set family_tech $::ivar(envs,CHOP)
  if {[string match "GFCN2*" $family_tech]} {
    set td_location_file $::env(PROJ_ARCHIVE)//arc/core_client/self_collateral/GFCN2CLIENTA0LATEST/standard/all_pin_placement.csv
    if {[file exists $td_location_file]} {
      printt "Using td_location_file $td_location_file"
    }
  }

  if {$td_location_file ne "" && [file exists $td_location_file]} {
    set in [open_file $td_location_file r]
    gets $in header
    set i 0
    foreach l [split $header ,] {
      set header_map([string map {\" {}} $l]) $i
      incr i
    }
    array set td_location {}
    while {[gets $in line] >= 0} {
      # full_name,"bounding_box.ll_x","bounding_box.ll_y","bounding_box.ur_x","bounding_box.ur_y","layer.name"

      set lline [split $line ,]
      set name [lindex $lline $header_map(full_name)]
      set x1 [lindex $lline $header_map(bounding_box.ll_x)]
      set y1 [lindex $lline $header_map(bounding_box.ll_y)]
      set x2 [lindex $lline $header_map(bounding_box.ur_x)]
      set y2 [lindex $lline $header_map(bounding_box.ur_y)]
      set metal [lindex $lline $header_map(layer.name)]
      set center_x [expr ($x1+$x2)/2]
      set center_y [expr ($y1+$y2)/2]
      catch {
        set td_location($name) [list [expr ${center_x}*1000] [expr ${center_y}*1000] [expr ${x1}*1000] [expr ${y1}*1000] [expr ${x2}*1000] [expr ${y2}*1000] $metal]
      }
    }
    close $in
  }
  set pins [get_pins {par_*/* icore0/par_*/*} -filter {direction==out}]

  set out [open $outfile w]
  puts $out "name,abutted,dist_to_bbox,st_point_x,st_point_y,en_point_x,en_point_y,port_point_x,port_point_y,port_point_x_abutted,port_point_y_abutted,fis_count,fos_count,wns,is_moved,td_x,td_y"
  set i 0

  foreach_in_collection pin $pins {
    set td_x ""
    set td_y ""
    if {[info exists td_location([get_attribute $pin full_name -q])]} {
      lassign $td_location([get_attribute $pin full_name -q]) td_x td_y
    }
    if {[catch {set dist_to_bbox [check_port_location_outside_bbox_fis_fos $pin $td_x $td_y]} err]} {
      echo "Error: $err [get_attribute $pin full_name]"
    } else {
      if {[llength $dist_to_bbox]} {
        puts $out [join $dist_to_bbox ,]
        if {[expr $i % 10000] == 0} {
          printt "Processed $i/[sizeof_collection $pins] pins"
        }
      }
    }
    incr i
  }
  close $out
}

proc check_port_location_outside_bbox_fis_fos {pin {td_x ""} {td_y ""}} {
  set diff_to_check 5000
  set name [get_attribute $pin full_name -q]
  set abutted_port [get_abutted_port $name]
  if {$abutted_port eq ""} {
    return {}
  }
  set fis [filter_collection [all_fanin -only_cells -startpoint -flat -to $pin -quiet] is_sequential&&defined(x_coordinate_min)]
  set fos [filter_collection [all_fanout -only_cells -endpoints_only -flat -from $pin -quiet] is_sequential&&defined(x_coordinate_min)]
  set c {}
  append_to_collection c $fis
  append_to_collection c $fos
  set sorted_cx [sort_collection $c x_coordinate_min]
  set sorted_cy [sort_collection $c y_coordinate_min]
  set st_point_x [get_attribute [index_collection $sorted_cx 0] x_coordinate_min -q]
  set st_point_y [get_attribute [index_collection $sorted_cy 0] y_coordinate_min -q]
  set en_point_x [get_attribute [index_collection $sorted_cx end] x_coordinate_max -q]
  set en_point_y [get_attribute [index_collection $sorted_cy end] y_coordinate_max -q]
  set pt_point_x [get_attribute $pin x_coordinate -q]
  set pt_point_y [get_attribute $pin y_coordinate -q]
  set dx 0
  set dy 0
  if {$td_x ne ""} {
    set port_point_x $td_x
  } else {
    set port_point_x $pt_point_x
  }
  if {$td_y ne ""} {
    set port_point_y $td_y
  } else {
    set port_point_y $pt_point_y
  }
  set diff 0
  set toout ""
  catch {
    set dx [expr abs($pt_point_x - $td_x)]
    set dy [expr abs($pt_point_y - $td_y)]
    set diff [expr {$dx + $dy}]
    if {$diff > $diff_to_check} {
      set toout moved
    }
  }
  set dist_to_bbox [check_port_location_outside_bbox $st_point_x $st_point_y $en_point_x $en_point_y $port_point_x $port_point_y]
  set wns [sio_mow_get_attrbute_by_delay_type $pin]
  set pin_abutted [get_pins $abutted_port]
  set port_point_x_abutted [get_attribute $pin_abutted x_coordinate -q]
  set port_point_y_abutted [get_attribute $pin_abutted y_coordinate -q]
  return [list $name $abutted_port $dist_to_bbox $st_point_x $st_point_y $en_point_x $en_point_y $pt_point_x $pt_point_y $port_point_x_abutted $port_point_y_abutted [sizeof_collection $fis] [sizeof_collection $fos] $wns $toout $td_x $td_y]
}

proc check_port_location_outside_bbox_tp {tp pin} {
  set port_point_x [get_attribute $pin x_coordinate -q]
  set port_point_y [get_attribute $pin y_coordinate -q]
  set st_point_x [get_attribute $tp startpoint.x_coordinate -q]
  set st_point_y [get_attribute $tp startpoint.y_coordinate -q]
  set en_point_x [get_attribute $tp endpoint.x_coordinate -q]
  set en_point_y [get_attribute $tp endpoint.y_coordinate -q]
  set dist_to_bbox [check_port_location_outside_bbox $st_point_x $st_point_y $en_point_x $en_point_y $port_point_x $port_point_y]
  return $dist_to_bbox
}
#get bbox poins and return o if inside or manh distance to bbox otherwide
proc check_port_location_outside_bbox {x1 y1 x2 y2 point_x point_y} {
  if {[lsearch [list $x1 $y1 $x2 $y2 $point_x $point_y] "U*"] != -1 || [lsearch [list $x1 $y1 $x2 $y2 $point_x $point_y] ""] != -1} {
    return ""
  }
  lassign [lsort -real [list $x1 $x2]] xl xh
  lassign [lsort -real [list $y1 $y2]] yl yh
  set dist 0.0
  set dist [expr $dist + (($xh < $point_x)?($point_x - $xh):0.0)]
  set dist [expr $dist + (($yh < $point_y)?($point_y - $yh):0.0)]
  set dist [expr $dist + (($xl > $point_x)?($xl - $point_x):0.0)]
  set dist [expr $dist + (($yl > $point_y)?($yl - $point_y):0.0)]
  return [expr $dist/1000]
}

proc printt {msg} {
  set l "#|[string repeat {-} [info level]] [date] $msg"
  echo $l
  flush stdout
}

proc arginfo  {}  {
  set proc [lindex [info level -1] 0]
  set which [uplevel [list namespace which -command $proc]]
  set l "$which"
  set i -1
  foreach arg [info args $which] {
    incr i
    set value [uplevel [list set $arg]]
    append l " {$value}"
  }
  return $l
}
proc check_regexs_buffs_invs {ref_name} {
  set family_tech $::ivar(envs,CHOP)
  global check_regexs_buffs_invs_${family_tech}
  # upvar $buffs_cells_arr buffs_cells
  if {![info exists check_regexs_buffs_invs_${family_tech}]} {
    # printt "Start: [arginfo] create"
    set regexs [get_regexs_buffs_invs_current]
    foreach_in_collection cell [get_lib_cells -of_objects [get_libs]] {
      set cell_name [get_attribute $cell base_name]
      set found 0
      foreach regex $regexs {
        if {[regexp $regex $cell_name]} {
          set found 1;
          break
        }
      }
      set check_regexs_buffs_invs_${family_tech}($cell_name) $found
    }
  }
  if {![info exists check_regexs_buffs_invs_${family_tech}($ref_name)]} {
    set check_regexs_buffs_invs_${family_tech}($ref_name) 0
  }
  return [set check_regexs_buffs_invs_${family_tech}($ref_name)]
}
proc sio_inv_buff_delay_to_endpoint_haya {tps {as_csv 0}} {
  set i 0
  set ret [list]

  foreach_in_collection tp $tps {
    set points [get_attribute $tp points]
    set j [expr [sizeof_collection $points] -1]
    while {$j && [get_attribute $tp endpoint.cell.full_name] eq [get_attribute [index_collection $points $j] object.cell.full_name]} {
      incr j -1
    }
    set point ""
    while {$j >= 0} {
      incr j -1
      set point [index_collection $points $j]
      if {[get_attribute -quiet $point object.cell.is_hierarchical] != ""} {
        set is_hier [get_attribute -quiet $point object.cell.is_hierarchical]
      }
      if {$is_hier} {
        continue
      }
      set is_inv_buff [check_regexs_buffs_invs [get_attribute $point object.cell.ref_name]]

      if {!$is_inv_buff} {
        break
      }
    }
    set manh_dist_unit [sio_manh_dist [get_attribute $tp endpoint] [get_attribute [index_collection $points $j] object]]
    set delay [expr [get_attribute [index_collection $points end] arrival]-[get_attribute [index_collection $points $j] arrival]]
    if {[catch {set speed [expr 100*((double($delay))/(double($manh_dist_unit)/1000))]}]} {
      set speed 0.0
    }
    set manh_dist [expr double($manh_dist_unit)/1000]
    lappend ret [join [list $i $manh_dist $delay $speed] ,]
    incr i
  }
  if {$as_csv} {
    puts "id,manh_dist,delay,delay/manh_dist"
    puts [join $ret \n]
  } else {
    return $ret
  }
}
proc sio_manh_dist {i o} {
  set pin1 $i
  set pin2 $o
  set x1 [get_attribute $pin1 x_coordinate -quiet]
  set x2 [get_attribute $pin2 x_coordinate -quiet]
  set y1 [get_attribute $pin1 y_coordinate -quiet]
  set y2 [get_attribute $pin2 y_coordinate -quiet]
  if {$x1 ne "" && $x2 ne "" && $y1 ne "" && $y2 ne "" && $x1 ne "UNINIT" && $x2 ne "UNINIT" && $y1 ne "UNINIT" && $y2 ne "UNINIT"} {
    return [expr {abs($x1-$x2)+abs($y1-$y2)}]
  }
  return ""
}

proc get_realted_percent {sp_x sp_y port_x port_y ep_x ep_y} {
  if {$sp_x eq "UNINIT" || $sp_y eq "UNINIT" || $port_x eq "UNINIT" || $port_y eq "UNINIT" || $ep_x eq "UNINIT" || $ep_y eq "UNINIT"} {
    return 0.5
  }
  return [expr double(abs($port_x - $sp_x) + abs($port_y - $sp_y))/(abs($port_x - $ep_x) + abs($port_y - $ep_y) + abs($port_x - $sp_x) + abs($port_y - $sp_y))]
}
proc get_realted_percent2 {sp_x sp_y port1_x port1_y port2_x port2_y ep_x ep_y} {
  if {$sp_x eq "UNINIT" || $sp_y eq "UNINIT" || $port1_x eq "UNINIT" || $port1_y eq "UNINIT" || $port2_x eq "UNINIT" || $port2_y eq "UNINIT" || $ep_x eq "UNINIT" || $ep_y eq "UNINIT"} {
    return 0.5
  }
  set dist1 [expr double(abs($port1_x - $sp_x) + abs($port1_y - $sp_y))]
  set dist2 [expr double(abs($port2_x - $ep_x) + abs($port2_y - $ep_y))]
  return [expr ($dist1 + $dist2)> 0?$dist1/($dist1 + $dist2):0.5]
}
proc get_partition_from_name {name {partitions {}}} {
  if {[llength $partitions] == 0} {
    set partitions [get_partitions]
  }
  set partition "/"
  foreach par $partitions {
    if {[string equal -length [string length "${par}/"] "${par}/" $name]} {
      set partition $par
    }
  }
  return $partition
}
proc get_partitions_from_name {names {partitions {}}} {
  set ret [list]
  if {[llength $partitions] == 0} {
    set partitions [get_partitions]
  }
  foreach name $names {
    set partition "/"
    foreach par $partitions {
      if {[string equal -length [string length "${par}/"] "${par}/" $name]} {
        set partition $par
      }
    }
    if {[lindex $ret end] ne $partition} {
      lappend ret $partition
    }
  }
  return $ret
}

proc get_partitions {} {
  set blocks [get_attribute [get_cells {icore*/* *} -quiet] full_name]
  set ret [list]
  foreach b2 $blocks {
    set matched 0
    foreach b $blocks {
      if {[string match "${b2}/*" $b]} {set matched 1; break}
    }
    if {!$matched} {lappend ret $b2}
  }
  return $ret
}

proc get_regexs_buffs_invs_N3 {} {
  lappend regexs {(^|__)NOT[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)(PT)?BUFF[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)BUFT[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)BUFY[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)DEL[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)GBUFF[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)GINV[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)(PT)?INV[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  return $regexs
}
proc get_regexs_buffs_invs_N2 {} {
  lappend regexs {(^|__)NOT[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)(PT)?BUFF[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)BUFT[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)BUFY[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)DEL[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)GBUFF[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)GINV[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  lappend regexs {(^|__)(PT)?INV[a-zA-Z0-9]+BWP[0-9]{3}[a-zA-Z0-9]+$}
  return $regexs
}

proc get_nbclass_cores {} {
  set cl [split $::env(__NB_CLASSRESERVATION) ,]
  foreach c $cl {
    if {[string match "cores=*" $c]} {
      return [lindex [split $c "="] end]
    }
  }
  return 2
}
proc get_regexs_buffs_invs_1278 {} {
  set regexs [list]
  lappend regexs {(^|_)(g|i)[a-z0-9]mbf[a-z0-9]{12}}
  lappend regexs {(^|_)(g|i)[a-z0-9]min[a-z0-9]{12}}
  lappend regexs {(^|_)(g|i)[a-z0-9]mpsi[a-z0-9]{11}}
  lappend regexs {(^|_)(g|i)[a-z0-9]mdsin[a-z0-9]{12}}
  lappend regexs {(^|_)(g|i)[a-z0-9]mdsbf[a-z0-9]{12}}
  return $regexs
}
proc get_regexs_buffs_invs_1280 {} {
  lappend regexs {(^|__)INV_.*$}
  lappend regexs {(^|__)BUF_.*$}
  return $regexs
}
proc get_regexs_buffs_invs_current {} {
  array set process_to_proc {p1278 get_regexs_buffs_invs_1278 pn3 get_regexs_buffs_invs_N3 pn2 get_regexs_buffs_invs_N2 p1280 get_regexs_buffs_invs_1280}

  set family_tech $::ivar(envs,CHOP)
  set process ""

  if {$family_tech eq "PNC78SERVER" || $family_tech eq "ryl_cpu" || $family_tech eq "CGC78CLIENT" || $family_tech eq "PNC78CLIENT" || $family_tech eq "LNC78CLIENT" } {
    set process p1278
  } elseif {$family_tech eq "PTLMEDIA78P3" || $family_tech eq "PTLC78P3"} {
    set process p1278
  } elseif {$family_tech eq "LNCN3"} {
    set process pn3
  } elseif {$family_tech eq "PNCN2H156P48" || $family_tech eq  "GFCN2CLIENT" || $family_tech eq  "GFCN2SERVER" } {
    set process pn2
  } elseif {$family_tech eq "PNC80CLIENT" || $family_tech eq "PNC80SERVER"} {
    set process p1280
  } else {
    foreach p {_drPROCESSNAME params,family_tech envs,family_tech techlib_attr_value,technology_name} {
      if {[info exists ::ivar($p)] && [info exists process_to_proc(p[set ::ivar($p)])]} {
        set process p[set ::ivar($p)]
        break
      }
    }
  }
  if {$process eq ""} {
    error "Uknown tech $family_tech"
  }
  return [[set process_to_proc($process)]]
}
proc nm_to_um {d} {
  if {$d eq ""} {return ""}
  return [expr double($d)/1000]
}
proc mktemp {{sub_dir ""}}  {
  global env
  set tmp_dir /tmp_proj/$::env(USER)/
  if {[info exists env(__NB_FEEDER_HOST)] && [info exists env(__NB_FEEDER_PORT)]} {
    set tmp_dir /tmp/netbatch/
  }
  set tmp_dir $tmp_dir/$sub_dir
  file mkdir -p $tmp_dir
  return [exec mktemp -d -p $tmp_dir]
}
proc pinfo  {proc {body 1}}  {
  set args [info args $proc]
  set args_list [list]
  foreach a $args {
    if [info default $proc $a d] {
      lappend args_list [list $a $d]
    }  else {
      lappend args_list $a
    }
  }
  if {!$body} {return $args_list}
  set body [info body $proc]
  append result "\n" proc " " $proc " " "{" $args_list "}"
  append result " {$body}"
  return $result
}

proc infoc  {string}  {
  join [lsort -dictionary [info commands $string*]] \n
}

proc server_buff_chain_server_get_xys {tp pre_start_id pre_mid_id post_mid_id post_end_id} {
  set points [get_attribute $tp points]
  set ret {}
  foreach_in_collection p [index_collection $points $pre_start_id $pre_mid_id] {
    catch {lappend ret [expr [get_attribute $p x_coordinate]/1000] [expr [get_attribute $p y_coordinate]/1000]}
  }
  foreach_in_collection p [index_collection $points $post_mid_id $post_end_id] {
    catch {lappend ret [expr [get_attribute $p x_coordinate]/1000] [expr [get_attribute $p y_coordinate]/1000]}
  }
  return $ret
}

proc server_buff_chain_server {chan addr port} {
  global until_time_to_stop

  printt "Start connection"
  fileevent $chan readable
  gets $chan line
  printt "Got: $line" ;# local logging
  if {$line eq "close"} {
    close $chan
    set until_time_to_stop 0
    return
  }
  fileevent $chan writable
  fconfigure $chan -buffering line ;
  printt "Run get_timing_paths"
  set tp [get_timing_paths -through $line]
  printt "Done get_timing_paths"

  redirect -channel $chan {report_timing -trans -physical -nets -nosplit -crosstalk_delta $tp}
  printt "Done report_timing"
  puts $chan "*****************************************************************"
  lassign [buff_chains_collect_data_new $tp $line buffs_arr] port_out pre post
  printt "buff_chains_collect_data_new report_timing"
  lassign $pre pre_manh_dist pre_tot_dist pre_delay pre_speed pre_buff_count pre_fan_out_sum pre_start_id pre_mid_id
  lassign $post post_manh_dist post_tot_dist post_delay post_speed post_buff_count post_fan_out_sum post_mid_id post_end_id
  puts $chan [join [server_buff_chain_server_get_xys $tp $pre_start_id $pre_mid_id $post_mid_id $post_end_id]]
  printt "close"
  close $chan
  printt "closed"
}

proc run_server_buff_chain_server {} {
  # source ~/ayarokh_wa/git/bei/scripts/tcl/sio_common.tcl
  # source ~/ayarokh_wa/git/bei/scripts/tcl/bei_chain_buffers_report.tcl
  global until_time_to_stop
  set host localhost
  set port 9900
  set server [socket -server server_buff_chain_server $port]
  vwait until_time_to_stop
  close $server
}
proc server_mow_server_get_xys {tp} {
  # set points [filter_collection [get_attribute $tp points] {object.pin_direction=="out" || object.is_hierarchical}]
  set points [get_attribute $tp points]
  set ret {}
  foreach_in_collection p $points {
    if {[string match *innovus [info nameofexecutable]]} {
      catch {lappend ret [expr [get_attribute $p x_coordinate]] [expr [get_attribute $p y_coordinate]]}
    } else {
      catch {lappend ret [expr [get_attribute $p x_coordinate]/1000] [expr [get_attribute $p y_coordinate]/1000]}
    }
  }
  return $ret
}

proc server_run_cmd_ohad args {
  global sio_cache
  if {![itcl::is class sio_cache_data]} {
    itcl::class sio_cache_data {
      private variable cached_ret
      private variable cached_tps
      private variable id_to_key
      private variable key_to_id
      private variable cached_tps_id 0
      constructor {} {
        array set cached_ret {}
        array set cached_tps {}
        array set id_to_key {}
        array set key_to_id {}
      }
      public method add {key value} {
        set cached_ret($key) $value
      }
      public method exists {key} {
        return [info exists cached_ret($key)]
      }
      public method get {key} {
        return $cached_ret($key)
      }
      public method getAllKeys {} {
        return [array keys cached_ret]
      }
      #return id
      public method addTps {key timing_path} {
        incr cached_tps_id
        set cached_tps($key) $timing_path
        set key_to_id($key) $cached_tps_id
        set id_to_key($cached_tps_id) $key
        return $cached_tps_id
      }
      public method getTps {key} {
        return $cached_tps($key)
      }
      public method getTpsById {id} {
        if {[info exists id_to_key($id)]} {
          set key $id_to_key($id)
          if {[info exists cached_tps($key)]} {
            return $cached_tps($key)
          }
        }
      }
    }
  }

  if {![itcl::is object sio_cache1]} {sio_cache_data sio_cache1}
  set sio_cache sio_cache1

  set params [join [lassign $args cmd] " "]
  return [server_run_cmd $cmd $params]
}
proc server_sio_mow_server2 {chan addr port} {
  global until_time_to_stop
  puts "[date] Start connection"
  fileevent $chan readable
  gets $chan line
  puts "[date] Got: $line" ;# local logging
  if {$line eq "close"} {
    close $chan
    set until_time_to_stop 0
    return
  }
  set params [join [lassign $line cmd] " "]
  fileevent $chan writable
  fconfigure $chan -buffering line
  redirect -channel $chan {server_run_cmd $cmd $params}
  puts "[date] Done $cmd"
  puts "[date] close"
  close $chan
  puts "[date] closed"
}

proc server_sio_mow_server_cadence {chan addr port} {
  global until_time_to_stop
  puts "Start connection server_sio_mow_server_cadence"
  fileevent $chan readable
  gets $chan line
  puts "Got: $line" ;# local logging
  if {$line eq "close"} {
    close $chan
    set until_time_to_stop 0
    return
  }
  set params [join [lassign $line cmd] " "]
  fileevent $chan writable
  fconfigure $chan -buffering line
  puts "Run $cmd $params"
  # redirect -channel $chan {server_run_cmd $cmd $params}
  redirect -variable out {server_run_cmd_cadence $cmd $params}
  puts $chan $out
  puts "Done $cmd"
  puts "close"
  close $chan
  puts "closed"
}
proc run_sio_mow_ryl {{fc2visio ""} {pt_port 9901}} {
  if {$fc2visio ne ""} {
    set ::sio_mow_lo_locations [join [sio_mow_parse_locations_ryl $fc2visio] "|"]
  }
  run_sio_mow "/dev/null" $pt_port
}
proc run_sio_mow {{output_file "/dev/null"} {pt_port 9901}} {
  global script_dir
  suppress_message MC-100
  echo "source [set to_source $script_dir/carpet.tcl]"
  source $to_source

  global sio_mow_jobids
  sio_mow_get_initial_data
  set sio_mow_dir [mktemp sio_mow]
  echo "Log dir: $sio_mow_dir"
  set py_port 8050
  set pt_host $::env(HOST)
  if {[info exists sio_mow_jobids(bg_server_py)]} {
    if {![catch {exec ps --pid [lindex $sio_mow_jobids(bg_server_py) 0]} err]} {
      echo "Closing PY server"
      if {[lindex $sio_mow_jobids(bg_server_py) 0] != [pid]} {
        exec kill -9 [lindex $sio_mow_jobids(bg_server_py) 0]
        after 5000
      }
    }
  }
  if {[info exists sio_mow_jobids(bg_server_pt)]} {
    if {![catch {exec ps --pid [lindex $sio_mow_jobids(bg_server_pt) 0]} err]} {
      echo "Closing PT server"
      sio_mow_close_pt_server [lindex $sio_mow_jobids(bg_server_pt) 1]
      after 5000
    }
  }

  set myLocation [file dirname $script_dir]
  printt "sio_mow_get_clk_target_get"
  set clktrget [sio_mow_get_clk_target_get]
  printt "Done sio_mow_get_clk_target_get"

  set bg_server_pt [redirect -file $sio_mow_dir/bg_server_pt.log -bg {run_server_sio_mow_server $pt_port $clktrget}]
  if {$output_file eq ""} {
    set output_file /dev/null
  }
  echo "Please run from any shell:\n $myLocation/carpet.run -new $output_file -out_file port_tns_file.report -pt_server_address $pt_host -pt_server_port $pt_port"
  set sio_mow_jobids(bg_server_pt) [list $bg_server_pt $pt_port]
  #echo "SERVER STARTED AT:"
  #echo "http://[set ::env(HOST)].[set ::env(EC_SITE)].intel.com:${py_port}"
}

proc sio_mow_close_pt_server {{port 9900}} {
  set server localhost
  set sockChan [socket $server $port]
  puts $sockChan "close"
  close $sockChan
  return 0
}
proc run_server_sio_mow_server {{port 9900} {clk_target {}}} {
  global sio_cache sio_mow_get_clk_target
  set sio_mow_get_clk_target $clk_target
  if {[itcl::is class sio_cache_data]} {
    itcl::delete class sio_cache_data
  }
  if {![info exist sio_cache] && ![itcl::is class sio_cache_data]} {
    itcl::class sio_cache_data {
      private variable cached_ret
      private variable cached_tps
      private variable id_to_key
      private variable key_to_id
      private variable cached_tps_id 0
      constructor {} {
        array set cached_ret {}
        array set cached_tps {}
        array set id_to_key {}
        array set key_to_id {}
      }
      public method add {key value} {
        set cached_ret($key) $value
      }
      public method exists {key} {
        return [info exists cached_ret($key)]
      }
      public method get {key} {
        return $cached_ret($key)
      }
      public method getAllKeys {} {
        return [array keys cached_ret]
      }
      #return id
      public method addTps {key timing_path} {
        incr cached_tps_id
        set cached_tps($key) $timing_path
        set key_to_id($key) $cached_tps_id
        set id_to_key($cached_tps_id) $key
        return $cached_tps_id
      }
      public method getTps {key} {
        return $cached_tps($key)
      }
      public method getTpsById {id} {
        if {[info exists id_to_key($id)]} {
          set key $id_to_key($id)
          if {[info exists cached_tps($key)]} {
            return $cached_tps($key)
          }
        }
      }
    }
  }
  if {[info exists sio_cache]} {unset sio_cache}
  if {![itcl::is object sio_cache1]} {sio_cache_data sio_cache1}
  set sio_cache sio_cache1
  set display ""
  if {[info exists ::env(DISPLAY)]} {
    set display $::env(DISPLAY)
    set ::env(DISPLAY) ""
  }
  echo "-pt_server_address [set ::env(HOST)] -pt_server_port $port"
  global until_time_to_stop
  if {[string match *innovus [info nameofexecutable] ]} {
    echo INNOVUS
    set server [socket -server server_sio_mow_server_cadence $port]
  } else {
    set server [socket -server server_sio_mow_server2 $port]
  }
  lassign [chan configure $server -sockname] serverAddress serverName serverPort
  if {!$port} {echo $::env(HOST):$serverPort}
  vwait until_time_to_stop
  close $server
  if {$display ne ""} {
    set ::env(DISPLAY) $display
  }
  unset sio_cache
}
proc get_ebb_names {} {
  return [get_attribute [get_lib_cells -of_objects [get_libs] -filter {is_black_box&&number_of_pins>1&&!is_combinational}] base_name]
}

proc sio_mow_get_arc_from {to} {
  set pin [get_pins $to]
  if {[get_attribute $pin direction] eq "in" && [expr ([get_attribute -quiet $pin cell.is_negative_level_sensitive] || [get_attribute -quiet $pin cell.is_positive_level_sensitive])]} {
    return "-from $to"
  }
  return "-from [get_attribute [get_cell -of_objects $pin] full_name]"
}
proc sio_mow_get_arc_to {from} {
  set pin [get_pins $from]
  if {[get_attribute $pin direction] eq "in" && [expr ([get_attribute -quiet $pin cell.is_negative_level_sensitive] || [get_attribute -quiet $pin cell.is_positive_level_sensitive])]} {
    return "-to $from"
  }
  if {![get_attribute $pin is_clock_pin]} {
    set pins [get_attribute [get_timing_arcs -from $pin -filter {is_cellarc&&!is_disabled&&!to_pin.is_clock_pin&&to_pin.direction=~in*}] to_pin.full_name]
    array set count {}
    foreach f $pins {
      if {$f eq $from} {continue}
      if {![info exists count($f)]} {
        set count($f) 1
      } else {
        incr count($f)
      }
    }
    set a [lindex [lindex [lsort -stride 2 -index 1 -integer -decreasing [array get count]] 0] 0]
    if {$a ne ""} {
      return "-to $a"
    }
  }
  return "-to [get_attribute [get_cell -of_objects $from] full_name]"
}
proc server_run_cmd_parse_params {params} {
  array set aparams [list f -from t -to th -through ex -exclude nw -nworst mp -max_paths slt -slack_lesser_than pba -pba_mode \
    gt sio_mow_get_arc_to gf sio_mow_get_arc_from from_id sio_cache_data_from_id]
  set return_as_is [list from_id]
  set bad_input [list bad_input -]
  set ret [list]
  foreach f [split $params " "] {
    set p [string first ":" $f]
    if {$p == -1} {return $bad_input}
    set arg [string range $f 0 [expr $p - 1]]
    if {![info exists aparams($arg)]} {
      return $bad_input
    }
    set val [string range $f [expr $p+1] end]
    if {[string equal -length 1 $aparams($arg) "-"]} {
      lappend ret "$aparams($arg) $val"
    } else {
      set r [$aparams($arg) $val]
      if {$r eq ""} {
        return $bad_input
      } else {
        if {[lsearch -ascii -exact $return_as_is $arg] != -1} {
          return [list $r tp]
        }
        lappend ret $r
      }
    }
  }
  return [list [join $ret " "] params]
}
proc sio_cache_data_from_id {id} {
  global sio_cache
  lassign [split $id /] a b
  set c [$sio_cache getTpsById $a]
  if {$b ne ""} {
    return [index_collection $c $b]
  }
  return $c
}
proc sio_mow_report_timing {paths pars} {
  set sig_didg 1
  set time_unit [sio_mow_get_time_unit]
  if {$time_unit eq "ns"} {set sig_didg 3}
  set path_type [get_attribute [index_collection $paths 0] path_type -quiet]
  if {[string match *innovus [info nameofexecutable] ]} {
    puts "> [string map {get_timing_paths report_timing} $pars] -hpin -split_delay\n\n"
    report_timing -hpin -split_delay ${paths}
  } else {
    # set delay_type [sio_mow_get_delay_type]
    puts "> [string map {get_timing_paths report_timing} $pars] -significant_digits $sig_didg -nosplit -nets -physical -input_pins -capacitance -transition_time -attributes points.object.${path_type}_slack\n\n"
    report_timing -significant_digits $sig_didg -nosplit -nets -physical -input_pins -capacitance -transition_time -crosstalk_delta -attributes [list object.${path_type}_slack "  "] ${paths}
  }
}
proc server_run_cmd {cmd params} {
  if {$params eq "None"} {
    return
  }
  global sio_cache
  set ret "# $cmd $params\n"
  if {[info procs ::Carpet::draw::get_allowed_commands] ne "" && [lsearch -exact [::Carpet::draw::get_allowed_commands]  $cmd] != -1} {
    set key "$cmd $params"
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        set data [::Carpet::draw::$cmd {*}$params]
        puts "Data:"
        puts $data
      }
      puts $ret
      $sio_cache add $key $ret
      puts $data
    }
  }
  if {$cmd eq "sio_logic_count_path" || $cmd eq "sio_logic_count_path_as_is"} {
    set key "$cmd $params"
    if {$cmd eq "sio_logic_count_path"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
      if {$pars eq "bad_input"} {
        puts "Error: problem with params: $cmd $params"
        return
      }
    } else {
      set pars $params
    }
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        if {$cmd eq "sio_logic_count_path"} {
          set pars "get_timing_paths $pars -include_hierarchical_pins -start_end_pair"
        } elseif {$cmd eq "sio_logic_count_path_as_is"} {
          set pars "get_timing_paths $pars -include_hierarchical_pins"
        }
        set paths [eval $pars]
        if {[sizeof_collection $paths]} {
          set cache_id [$sio_cache addTps $key $paths]
          suppress_message {ATTR-1}
          puts "Cache_id:\n$cache_id"
          set table_text [join [sio_logic_count_path $paths 1 1] "\n"]
          puts "Table:"
          puts $table_text
          lassign [sio_mow_tp_points_of_interess_many_paths $paths] coords interes
          unsuppress_message {ATTR-1}
          foreach p $coords {
            puts "Coordinates:"
            puts [join $p " "]
          }
          puts "PointsInteress:"
          puts $interes

          # echo "SankeyData:"
          # echo [tps_to_sankey $paths]
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "sio_all_fanin_fanout_through_port" || $cmd eq "sio_all_fanin_fanout"} {
    set key "$cmd $params"
    if {$cmd eq "sio_all_fanin_fanout_through_port"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
      if {$pars eq "bad_input"} {
        puts "Error: problem with params: $cmd $params"
        return
      }
    } else {
      set pars $params
    }

    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        set pars "sio_all_fanin_fanout_through_port $pars"
        set paths [eval $pars]

        if {[sizeof_collection $paths]} {
          set cache_id [$sio_cache addTps $key $paths]
          puts "Cache_id:\n$cache_id"
          set table_text [join [sio_logic_count_path $paths 1 1] "\n"]
          puts "Table:"
          puts $table_text
          lassign [sio_mow_tp_points_of_interess_many_paths $paths] coords interes
          foreach p $coords {
            puts "Coordinates:"
            puts [join $p " "]
          }
          puts "PointsInteress:"
          puts $interes

          # echo "SankeyData:"
          # echo [tps_to_sankey $paths]
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "sio_min_delay_report_logic_count_path"} {
    set key "$cmd $params"
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      set ret [eval $key]
      $sio_cache add $key $ret
      puts "Text:"
      puts $ret
    }
  }
  if {$cmd eq "sio_logic_count_path_get_max_slack_real_run_tp"} {
    set key "$cmd $params"
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      set ret [eval $key]
      $sio_cache add $key $ret
      puts "Text:"
      puts $ret
    }
  }
  if {$cmd eq "report_timing" || $cmd eq "report_timing_as_is"} {
    set key "$cmd $params"
    set pars_type other
    if {$cmd eq "report_timing"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
    } else {
      set pars $params
    }
    if {$pars eq "bad_input"} {
      puts "Error: problem with params: $cmd $params"
      return
    }

    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        # set paths [eval $pars]
        if {$pars_type eq "tp"} {
          set paths $pars
        } else {
          set pars "get_timing_paths $pars -include_hierarchical_pins"
          set paths [eval $pars]
        }
        set debug_i 0
        if {[sizeof_collection $paths]} {
          puts "Text:"
          suppress_message {ATTR-1}
          sio_mow_report_timing $paths $pars

          foreach_in_collection path $paths {
            puts "Coordinates:"
            puts [join [server_mow_server_get_xys $path] " "]
            puts "PointsInteress:"
            puts [sio_mow_tp_points_of_interess $path]
          }


          array unset prev_next
          set t [sio_mow_check_spec_csv $paths]
          puts "Table:"
          puts $t
          array set prev_next [get_to_and_from_from_tp [index_collection $paths 0]]
          set data_to_send [list]
          foreach prev_next_key {prev next} {
            if {[info exists prev_next($prev_next_key)]} {
              array set prev_next_data $prev_next($prev_next_key)
              set prev_cycle_args ""
              if {[info exists prev_next_data(args)]} {
                set prev_cycle_args $prev_next_data(args)
              }
              if {$prev_cycle_args ne ""} {
                lappend data_to_send "\"$prev_next_key\":\"$prev_cycle_args\""
              }
              array unset prev_next_data
            }
          }
          if {[llength $data_to_send]} {
            puts "Data:"
            puts "{\"prev_next\":{[join $data_to_send ,]}}"
          }
          unsuppress_message {ATTR-1}
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "sio_mow_get_initial_data"} {
    puts "Text:"
    set t [sio_mow_get_initial_data]
  }
  if {$cmd eq "sio_mow_get_all_ports"} {
    set t [join [sio_mow_get_all_ports 1] "\n"]
    puts "Table:"
    puts $t
  }
  if {$cmd eq "ping"} {
    set t [join [sio_mow_get_all_ports 1] "\n"]
    puts "Text:"
    puts 1
  }
  if {$cmd eq "free_command"} {
    puts "Text:"
    eval $params
  }
}

proc server_run_cmd_cadence {cmd params} {
  if {$params eq "None"} {
    return
  }
  global sio_cache
  set ret "# $cmd $params\n"
  if {$cmd eq "sio_logic_count_path" || $cmd eq "sio_logic_count_path_as_is"} {
    set key "$cmd $params"
    if {$cmd eq "sio_logic_count_path"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
      if {$pars eq "bad_input"} {
        puts "Error: problem with params: $cmd $params"
        return
      }
    } else {
      set pars $params
    }
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        if {$cmd eq "sio_logic_count_path"} {
          set pars "get_timing_paths $pars -include_hierarchical_pins -start_end_pair"
        } elseif {$cmd eq "sio_logic_count_path_as_is"} {
          set pars "get_timing_paths $pars -include_hierarchical_pins"
        }
        set paths [eval $pars]

        if {[sizeof_collection $paths]} {
          set cache_id [$sio_cache addTps $key $paths]
          suppress_message {ATTR-1}
          puts "Cache_id:\n$cache_id"
          set table_text [join [sio_logic_count_path $paths 1 1] "\n"]
          puts "Table:"
          puts $table_text
          lassign [sio_mow_tp_points_of_interess_many_paths $paths] coords interes
          unsuppress_message {ATTR-1}
          foreach p $coords {
            puts "Coordinates:"
            puts [join $p " "]
          }
          puts "PointsInteress:"
          puts $interes

          # echo "SankeyData:"
          # echo [tps_to_sankey $paths]
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "sio_all_fanin_fanout_through_port" || $cmd eq "sio_all_fanin_fanout"} {
    set key "$cmd $params"
    if {$cmd eq "sio_all_fanin_fanout_through_port"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
      if {$pars eq "bad_input"} {
        puts "Error: problem with params: $cmd $params"
        return
      }
    } else {
      set pars $params
    }

    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        set pars "sio_all_fanin_fanout_through_port $pars"
        set paths [eval $pars]

        if {[sizeof_collection $paths]} {
          set cache_id [$sio_cache addTps $key $paths]
          puts "Cache_id:\n$cache_id"
          set table_text [join [sio_logic_count_path $paths 1 1] "\n"]
          puts "Table:"
          puts $table_text
          lassign [sio_mow_tp_points_of_interess_many_paths $paths] coords interes
          foreach p $coords {
            puts "Coordinates:"
            puts [join $p " "]
          }
          puts "PointsInteress:"
          puts $interes

          # echo "SankeyData:"
          # echo [tps_to_sankey $paths]
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "report_timing" || $cmd eq "report_timing_as_is"} {
    set key "$cmd $params"
    set pars_type other
    if {$cmd eq "report_timing"} {
      lassign [server_run_cmd_parse_params $params] pars pars_type
    } else {
      set pars $params
    }
    if {$pars eq "bad_input"} {
      puts "Error: problem with params: $cmd $params"
      return
    }
    if {[$sio_cache exists $key]} {
      puts [$sio_cache get $key]
    } else {
      redirect -variable ret {
        # set paths [eval $pars]
        if {$pars_type eq "tp"} {
          set paths $pars
        } else {
          set pars "get_timing_paths $pars -include_hierarchical_pins"
          set paths [eval $pars]
        }
        if {[sizeof_collection $paths]} {
          puts "Text:"
          suppress_message {ATTR-1}
          sio_mow_report_timing $paths $pars

          foreach_in_collection path $paths {
            puts "Coordinates:"
            puts [join [server_mow_server_get_xys $path] " "]

            puts "PointsInteress:"
            puts [sio_mow_tp_points_of_interess $path]
          }

          array unset prev_next
          set table_text [join [invs_get_path_details $path 1 1] "\n"]
          puts "Table:"
          puts $table_text
          array set prev_next [get_to_and_from_from_tp [index_collection $paths 0]]
          set data_to_send [list]
          foreach prev_next_key {prev next} {
            if {[info exists prev_next($prev_next_key)]} {
              array set prev_next_data $prev_next($prev_next_key)
              set prev_cycle_args ""
              if {[info exists prev_next_data(args)]} {
                set prev_cycle_args $prev_next_data(args)
              }
              if {$prev_cycle_args ne ""} {
                lappend data_to_send "\"$prev_next_key\":\"$prev_cycle_args\""
              }
              array unset prev_next_data
            }
          }
          if {[llength $data_to_send]} {
            puts "Data:"
            puts "{\"prev_next\":{[join $data_to_send ,]}}"
          }
          unsuppress_message {ATTR-1}
        } else {
          puts "Error: NO DATA for $params"
        }
      }
      $sio_cache add $key $ret
      puts $ret
    }
  }
  if {$cmd eq "sio_mow_get_initial_data"} {
    puts "Text:"
    set t [sio_mow_get_initial_data]
  }
  if {$cmd eq "sio_mow_get_all_ports"} {
    set t [join [sio_mow_get_all_ports 1] "\n"]
    puts "Table:"
    puts $t
  }
  if {$cmd eq "ping"} {
    set t [join [sio_mow_get_all_ports 1] "\n"]
    puts "Text:"
    puts 1
  }
  if {$cmd eq "free_command"} {
    puts "Text:"
    eval $params
  }
}
proc cells_cataloging {cells} {
  set buff_invs 0
  set seqs 0
  set logic 0
  set hiers 0
  set latches 0
  set last_full_name ""
  foreach_in_collection cell $cells {
    set full_name  [get_attribute -quiet $cell full_name]
    if {$last_full_name eq $full_name} {
      continue
    }

    set ref_name  [get_attribute -quiet $cell ref_name]
    set is_buff_inv [check_regexs_buffs_invs $ref_name]
    set is_combinational [get_attribute -quiet $cell is_combinational]
    set is_hierarchical [get_attribute -quiet $cell is_hierarchical]
    set is_sequential [get_attribute -quiet $cell is_sequential]
    set is_black_box [get_attribute -quiet $cell is_black_box]
    if {!$is_hierarchical && !$is_black_box} {
      if {$is_buff_inv} {
        incr buff_invs
      } elseif {$is_sequential} {
        incr seqs
        if {[expr ([get_attribute -quiet $cell is_negative_level_sensitive] || [get_attribute -quiet $cell is_positive_level_sensitive])]} {
          incr latches
        }
      } elseif {$is_combinational} {
        incr logic
      }
    } else {
      incr hiers
    }
    set last_full_name $full_name
  }
  return [list $buff_invs $logic $seqs $latches $hiers]
}
proc get_ports_from_points {points {ports_as_list 0} {partitions {}}} {
  set last_full_name [get_attribute [index_collection $points 0] object.full_name]
  if {[llength $partitions]} {
    set partitions [get_partitions]
  }
  set last_name [get_partition_from_name $last_full_name $partitions]
  set pars [list $last_name]
  set ports []
  foreach full_name [get_attribute $points object.full_name] {
    set name [get_partition_from_name $full_name $partitions]
    if {$name ne $last_name} {
      lappend pars $name
      if {$ports_as_list} {
        lappend ports [list $last_full_name $full_name]
      } else {
        lappend ports "( $last_full_name $full_name )"
      }
    }
    set last_name $name
    set last_full_name $full_name
  }
  return [list $pars $ports]
}
proc sio_logic_count_path_get_max_slack_real_run_tp {args} {
  set tp [get_timing_path {*}[lindex $args 0]]
  set header "min_of(max_slack)_(minimum_max_slack)_path_from_min_corner,max_of(max_slack)_(maximum_max_slack)_path_from_min_corner"
  return "${header}\n[join [lindex [sio_logic_count_path_get_max_slack_real $tp [lindex $args 1]] 0] ,]"
}
proc sio_mow_get_attrbute_by_delay_type {by} {
  set delay_type max_slack
  set delay_type_default max
  if {[info exists ::ivar(sta,delay_type)]} {
    set delay_type [set ::ivar(sta,delay_type)]_slack
  } else {
    set delay_type ${delay_type_default}_slack
  }
  return [get_attribute $by $delay_type]
}
proc sio_mow_get_delay_type {{delay_type_default max}} {
  set delay_type $delay_type_default
  if {[info exists ::ivar(sta,delay_type)]} {
    set delay_type $::ivar(sta,delay_type)
  }
  return $delay_type
}
# to_run - any parameter, e.g. {-pba path}
# all_points - list of points,
#      the first point is start point,
#      the last point is endpoint,
#      between first and last are -through points
proc sio_mow_min_delay_min_max_logic_count {to_run {all_points {}}} {
  set delay_type [sio_mow_get_delay_type]
  set default_args [list -delay_type $delay_type {*}$to_run]
  lappend args_for_timing_paths {*}$default_args -include_hierarchical_pins
  if {[llength $all_points] > 1} {
    lappend args_for_timing_paths -from [lindex $all_points 0] -to [lindex $all_points end]
    if {[llength $all_points] > 2} {
      lappend args_for_timing_paths -through [lrange $all_points 1 end-1]
    }
  }
  set tp [get_timing_paths {*}$args_for_timing_paths]
  if {[sizeof_collection $tp] == 0} {return}

  lassign [sio_logic_count_path $tp 1] header data

  if {$delay_type ne "min" && [llength $all_points] > 1} {
    set args_for_paths $default_args
    set r [list]
    foreach p [lrange $all_points 1 end] {
      lappend r [list -through $p {*}$args_for_paths]
    }
    # lappend r [list -to [lindex $all_points end] {*}$args_for_paths]
    set rdata [sio_logic_count_path_get_max_slack_real_from_points $r]
    lassign [lindex $rdata end] _ maximum_max_slack rpoints
    append header , "max_of(max_slack)_(maximum_max_slack)_path_from_min_corner" , slack_to_endpoint , debug_data
    append data , $maximum_max_slack , [lindex [lindex $rpoints end] end] , $rpoints
  } else {
    set all_points [join [get_attribute $tp points.object.full_name] " "]
    append header , all_points
    append data , $all_points
  }
  return [join [list $header $data] \n]
}

proc run_client_for_sio_mow_min_delay_min_max_logic_count {server port name start end} {
  set d [sio_mow_client_api new $server $port $name $start $end]
  if {[$d needMe]} {
    $d api
  }
  $d destroy
}
proc run_client_for_sio_mow_min_delay_check_if_exit {server port name start end} {
  set d [sio_mow_client_api new $server $port $name $start $end]
  if {![$d needMe]} {
    $d destroy
    exit
  }
}

# args - list of lists, each item will be used as input to get_timing_paths
proc sio_logic_count_path_get_max_slack_real_from_points {data} {
  set min_slack inf
  set max_slack -inf
  set ret [list]
  foreach arg $data {
    set paths [get_timing_paths {*}$arg]
    foreach_in_collection tp $paths {
      set slack [get_attribute $tp slack]
      set endpoint [get_attribute $tp endpoint.full_name]
      lappend per_point_data [list $arg $slack $endpoint]
      catch {
        set min_slack [expr min($slack,$min_slack)]
        set max_slack [expr max($slack,$max_slack)]
      }
    }
    lappend ret [list $min_slack $max_slack $per_point_data]
  }
  return $ret
}
proc sio_logic_count_path_get_max_slack_real {paths {tp_args {}}} {
  array set cache {}
  set ret [list]
  foreach_in_collection tp $paths {
    set min_slack inf
    set max_slack -inf
    set points [get_attribute $tp points]
    set i 0
    foreach_in_collection point $points {
      incr i
      set name [get_attribute $point object.full_name]
      if {![info exists cache($name)]} {
        if {$i == [sizeof_collection $points]} {
          set tp_through [get_timing_path -to [get_attribute $point object] {*}$tp_args]
        } elseif {$i == 1} {
          set sp [get_startpoint_real_name $points]
          if {$name ne $sp} {
            set tp_through [get_timing_path -from [get_attribute $point object] -through $sp {*}$tp_args]
          } else {
            set tp_through [get_timing_path -from [get_attribute $point object] {*}$tp_args]
          }
        } else {
          set tp_through [get_timing_path -through [get_attribute $point object] {*}$tp_args]
        }
        set slack [get_attribute $tp_through slack]
        set cache($name) $slack
      }
      set slack $cache($name)
      catch {
        set min_slack [expr min($slack,$min_slack)]
        set max_slack [expr max($slack,$max_slack)]
      }
    }
    lappend ret [list $min_slack $max_slack]
  }
  return $ret
}
proc sio_logic_count_path_get_max_slack {paths} {
  array set cache {}
  set ret [list]
  foreach_in_collection tp $paths {
    set min_slack inf
    set max_slack -inf
    set points [get_attribute $tp points]
    foreach_in_collection point [index_collection $points 1 end-1] {
      set name [get_attribute $point object.full_name]
      if {![info exists cache($name)]} {
        set slack [get_attribute $point object.max_slack]
        set cache($name) $slack
      }
      set slack $cache($name)
      catch {
        set min_slack [expr {$slack < $min_slack?$slack:$min_slack}]
        set max_slack [expr {$slack > $max_slack?$slack:$max_slack}]
      }
    }
    lappend ret [list $min_slack $max_slack]
  }
  return $ret
}

proc sio_logic_count_path_check_all_ports {{paths {}}} {
  if {[llength $paths] == 0} {
    set pins [get_pins {icore0/par_*/* par_*/*} -filter direction==out]
    set count 0
    printt "Processing [sizeof_collection $pins] pins"
    foreach_in_collection pin $pins {
      append_to_collection paths [get_timing_paths -th $pin -to mclk_* -include_hierarchical_pins]
      echo [incr count]/[sizeof_collection $pins]
    }
  }
  printt "Start sio_logic_count_path [sizeof_collection $paths] paths"
  set out [sio_logic_count_path $paths 1 1 1]
  printt "Done sio_logic_count_path [sizeof_collection $paths] paths"
  echo [join $out \n] > /nfs/site/disks/ayarokh_wa/tmp/sio_logic_count_path_check_all_ports.csv
  return $paths
}

proc sio_logic_count_path_check_ooo_vec {{paths {}}} {
  if {[llength $paths] == 0} {
    set pins [get_pins icore0/par_ooo_vec/*]
    set count 0
    printt "Processing [sizeof_collection $pins] pins"
    foreach_in_collection pin $pins {
      append_to_collection paths [get_timing_paths -th $pin -to mclk_* -include_hierarchical_pins]
      echo [incr count]/[sizeof_collection $pins]
    }
    printt "Done get_timing_paths [sizeof_collection $pins] pins"
  }
  printt "Start sio_logic_count_path [sizeof_collection $paths] paths"
  set out [sio_logic_count_path $paths 1 1 1]
  printt "Done sio_logic_count_path [sizeof_collection $paths] paths"
  echo [join $out \n] > ooo_vec_paths_spec.csv
  return $paths
}

proc sio_logic_count_path {paths {add_header 0} {add_index 0} {prev_next_noneed 0}} {
  set _sio_ovr_buffer_string _sio_ovr_buffer
  set partitions [get_partitions]
  set header [list]
  if {$add_index} {
    lappend header "id"
  }
  # lappend header slack cycles norm_slack startCLK endCLK startPointType startPoint endPointType endPoint prev_cycle_slack next_cycle_slack sio_buffs_delay logic_cells buff/inv seq ports pars minimum_(max_slack_on_path) maximum_(max_slack_on_path) path_group prev_args next_args
  lappend header slack cycles norm_slack skew startCLK endCLK startPointType startPoint endPointType endPoint prev_cycle_slack next_cycle_slack sio_buffs_delay sio_pteco_delay logic_cells logic_cell_delay buff/inv seq ports pars maximum_(max_slack_on_path) path_group end_point_period clock_uncertainty required manhattan_dist total_dist statistical_adjustment tip_delay tip_dist port_drv port_rcv startPoint_tooltip
  if {!$prev_next_noneed} {lappend header prev_args next_args}
  set sio_logic_count_path_get_max_slack_data [sio_logic_count_path_get_max_slack $paths]
  set out [list]
  if {$add_header} {lappend out [join $header ,]}
  set id 0
  foreach_in_collection path $paths {
    set line ""
    set partitions [get_partitions]
    set slack [get_attribute -quiet ${path} slack]
    set points [get_attribute -quiet ${path} points]
    lassign [sio_mow_get_sio_buffer_data_from_paths $path] sio_buffs_delay count_sio_ovr_buffer
    lassign [sio_mow_get_sio_buffer_data_from_paths $path PTECO_HOLD_*] sio_pteco_delay sio_pteco_count

    lassign [cells_cataloging [get_attribute -quiet $points object.cell]] buff_invs logic seqs latches hiers
    lassign [lindex $sio_logic_count_path_get_max_slack_data $id] min_slack_on_path max_slack_on_path

    set start_point [get_attribute ${path} startpoint.full_name]
    set end_point [get_attribute ${path} endpoint.full_name]
    array set prev_next [get_to_and_from_from_tp $path]
    set prev_cycle_args NA
    set prev_cycle_slack NA
    if {[info exists prev_next(prev)]} {
      array set prev_next_prev $prev_next(prev)
      if {[info exists prev_next_prev(max_slack)]} {
        set prev_cycle_slack $prev_next_prev(max_slack)
      }
      if {[info exists prev_next_prev(args)]} {
        set prev_cycle_args $prev_next_prev(args)
      }
      array unset prev_next_prev
    }
    set next_cycle_args NA
    set next_cycle_slack NA
    if {[info exists prev_next(next)]} {
      array set prev_next_next $prev_next(next)
      if {[info exists prev_next_next(max_slack)]} {
        set next_cycle_slack $prev_next_next(max_slack)
      }
      if {[info exists prev_next_next(args)]} {
        set next_cycle_args $prev_next_next(args)
      }
      array unset prev_next_next
    }
    array unset prev_next
    set start_point_clk [get_attribute -quiet ${path} startpoint_clock_latency ]
    set end_point_clk [get_attribute -quiet ${path} endpoint_clock_latency ]
    set endpoint_clock [ get_attribute -quiet  ${path} endpoint_clock.full_name ]

    if {[info exists ::periodCache($endpoint_clock,$::clock_scenario)]} {
      set end_point_period $::periodCache($endpoint_clock,$::clock_scenario)
    } else {
      set end_point_period [get_attribute -quiet ${path} endpoint_clock.period]
    }
    set normilize_slack_perc [get_attribute -quiet  ${path} normalized_slack_no_close_edge_adjustment]
    if { $normilize_slack_perc eq "" } {
      set normilize_slack_perc [get_attribute -quiet  ${path} normalized_slack]
    }
    if {!($normilize_slack_perc eq "" || $normilize_slack_perc eq "UNINIT") && [info exists ::periodCache($endpoint_clock,$::clock_scenario)]} {
      set normilize_slack [expr $normilize_slack_perc*$::periodCache($endpoint_clock,$::clock_scenario)]
    } else {
      set normilize_slack ""
    }
    lassign [get_ports_from_points $points 0 $partitions] pars ports

    set manhattan_dist NA
    set total_dist NA
    catch {
      lassign [sio_mow_tot_dist_from_points $path] manhattan_dist total_dist
    }
    set start_point_type [sio_cell_type_by_pin [get_attribute -quiet ${path} startpoint]]
    set end_point_type [sio_cell_type_by_pin [get_attribute -quiet ${path} endpoint]]
    set path_group [get_attribute -quiet ${path} path_group.full_name]
    set clock_uncertainty [get_attribute -quiet $path clock_uncertainty]
    set required NA
    catch {
      set required [expr [get_attribute -quiet $path required] + [get_attribute -quiet $path endpoint_clock_close_edge_value]]
    }
    set tip_delay 0
    set tip_dist 0
    catch {
      lassign [sio_mow_tip_data $points] tip_delay tip_dist
    }
    set logic_cell_delay [sio_mow_logic_delay_from_points $path]
    set statistical_adjustment [get_attribute -quiet $path statistical_adjustment]
    set sep " "
    set ports_compressed [sio_mow_get_ports_from_path $path]
    set skew NA
    catch {set skew [expr $end_point_clk - $start_point_clk]}
    set startPoint_tooltip "[get_attribute -quiet [index_collection [get_attribute -quiet ${path} points] 1] object.full_name]"
    if {![string match "*MBIT*" $startPoint_tooltip]} {
      set startPoint_tooltip [get_attribute -quiet ${path} startpoint.full_name]
    }
    # append line "$slack,[expr $seqs /2.0 ],$normilize_slack,$start_point_clk,$end_point_clk,$start_point_type,$start_point,$end_point_type,$end_point,$prev_cycle_slack,$next_cycle_slack,$sio_buffs_delay,$logic,$buff_invs,$seqs,\"[join $ports $sep]\",$pars,$min_slack_on_path,$max_slack_on_path,$path_group,\"$prev_cycle_args\",\"$next_cycle_args\""
    append line "$slack,[expr $seqs /2.0 ],$normilize_slack,$skew,$start_point_clk,$end_point_clk,$start_point_type,$start_point,$end_point_type,$end_point,$prev_cycle_slack,$next_cycle_slack,$sio_buffs_delay,$sio_pteco_delay,$logic,$logic_cell_delay,$buff_invs,$seqs,\"[join $ports $sep]\",$pars,$max_slack_on_path,$path_group,$end_point_period,$clock_uncertainty,$required,$manhattan_dist,$total_dist,$statistical_adjustment,$tip_delay,$tip_dist,[lindex $ports_compressed 0],[lindex $ports_compressed 1],$startPoint_tooltip"
    if {!$prev_next_noneed} {
      append line , \"$prev_cycle_args\" , \"$next_cycle_args\"
    }
    # can add here post_eval for parallel, removed
    if {$add_index} {
      set line "$id,$line"
    }
    lappend out $line
    incr id
  }
  return $out
}

proc sio_mow_get_ports_from_path {path} {
  global compress_pin_name_arr
  set points [get_attribute -quiet $path points]
  lassign [get_ports_from_points $points 0] pars ports
  set ports [string trim [string map {\{ "" \( "" \} "" \) ""}  $ports]]
  return [list [compress_pin_name [lindex $ports 0]]  [compress_pin_name [lindex $ports end]]]
}

proc sio_mow_logic_delay_from_points {path} {
  set total_delay 0.0
  set points [get_attribute -quiet $path points]
  set last_arrival -1
  foreach_in_collection point [index_collection $points 1 end-1] {
    set is_hierarchical [get_attribute $point object.cell.is_hierarchical]
    if {$is_hierarchical eq ""} {
      set is_hierarchical 0
    }
    set arrival [get_attribute -quiet $point arrival]
    if {[check_regexs_buffs_invs [get_attribute $point object.cell.ref_name]] \
      || $is_hierarchical \
        || [get_attribute $point object.direction] eq "in"} {
        set last_arrival $arrival
      continue
    }
    if {$last_arrival ne -1} {
      set total_delay [expr $total_delay + ($arrival - $last_arrival)]
    }
  }
  return $total_delay
}

proc sio_mow_tip_data {points} {
  set tip_dist 0.0
  set tip_delay 0.0
  set tip [filter_collection $points object.full_name=~*/tip_cell_*]
  if {[sizeof_collection $tip] > 0} {
    set tip_point_0 [index_collection $tip 0]
    set tip_point_end [index_collection $tip end]
    set x_start [get_attribute -quiet ${tip_point_0} x_coordinate]
    set y_start [get_attribute -quiet ${tip_point_0} y_coordinate]
    set x_end [get_attribute -quiet ${tip_point_end} x_coordinate]
    set y_end [get_attribute -quiet ${tip_point_end} y_coordinate]
    set tip_dist [expr {(abs($x_start - $x_end) + abs($y_start - $y_end))/1000.0}]
    set tip_delay [expr [get_attribute -quiet ${tip_point_end} arrival] - [get_attribute -quiet ${tip_point_0} arrival]]
  }
  return [list $tip_delay $tip_dist]
}
proc sio_mow_tot_dist_from_points {path} {
  set total_dist 0
  set manhattan_dist 0
  set points [get_attribute -quiet $path points]
  set last_x -1
  set last_y -1
  foreach_in_collection point [filter_collection $points defined(x_coordinate)&&defined(y_coordinate)] {
    set x [get_attribute -quiet $point object.x_coordinate]
    set y [get_attribute -quiet $point object.y_coordinate]
    if {$x eq "" || $y eq ""} {
      continue
    }
    if {$last_x ne -1 && $last_y ne -1} {
      set total_dist [expr $total_dist + abs($x - $last_x) + abs($y - $last_y)]
    }
    set last_x $x
    set last_y $y
  }

  set x_start [get_attribute -quiet ${path} startpoint.x_coordinate]
  set y_start [get_attribute -quiet ${path} startpoint.y_coordinate]
  set x_end [get_attribute -quiet ${path} endpoint.x_coordinate]
  set y_end [get_attribute -quiet ${path} endpoint.y_coordinate]
  set manhattan_dist NA
  set manhattan_dist [expr {(abs($x_start - $x_end) + abs($y_start - $y_end))/1000.0}]
  return [list $manhattan_dist [expr $total_dist/1000.0]]
}

proc sio_session_name_get {{name "-"}} {
  if {$name ne "-" && [string trim $name] ne ""} {
    return $name
  }
  if {[info exists ::sio_session_name]} {
    set name $::sio_session_name
  } else {
    if {[info exists ::ivar]} {
      if {[info exists ::ivar(task)]} {
        set name $::ivar(task)
      } else {
        set name -
      }
    }
  }
  return $name
}
proc sio_mow_get_initial_data {} {
  set proj_archive "-"
  set td_collateral_tag "-"
  set product_name "-"
  set block "-"
  set name [sio_session_name_get]

  if {[info exists ::ivar]} {
    set proj_archive $::ivar(envs,PROJ_ARCHIVE)
    set td_collateral_tag $::ivar(fct_setup_cfg,TD_COLLATERAL_TAG)
    set product_name $::ivar(envs,CHOP)
    set block $::ivar(design_name)
  } else {
    if {[info exists ::env(PROJ_ARCHIVE)]} {set proj_archive $::env(PROJ_ARCHIVE)}
    if {[info exists ::env(TD_COLLATERAL_TAG)]} {set td_collateral_tag $::env(TD_COLLATERAL_TAG)}
    if {[info exists ::env(AREA_NAME)]} {set product_name $::env(AREA_NAME)}
    set block [get_attribute [current_design] full_name]
  }
  set stepping NONE
  if {[info exists ::env(STEPPING)]} {set stepping $::env(STEPPING)}

  if {$::env(USER) eq "ayarokh" && $product_name eq "PNC78SERVER"} {
    set product_name test
  }

  puts "PROJ_ARCHIVE $proj_archive"
  puts "TD_COLLATERAL_TAG $td_collateral_tag"
  puts "PRODUCT_NAME $product_name"
  puts "STEPPING $stepping"
  puts "block $block"
  puts "name $name"
  puts "time_unit [sio_mow_get_time_unit]"
  puts "delay_type [sio_mow_get_delay_type]"
  if {[info exist ::sio_mow_lo_locations]} {
    puts "lo_locations $::sio_mow_lo_locations"
  }
}
proc sio_mow_get_all_ports {{add_header 0}} {
  set header [list port wns direction abutted_port]
  set blocks [get_partitions]
  set pins [get_pins -of_objects $blocks -filter {direction=~in*}]
  set out [list]
  if {$add_header} {
    lappend out [join $header ,]
  }
  set delay_type max_slack
  if {[string match *min* $::ivar(sta,delay_type)]} {
    set delay_type min_slack
  }
  foreach_in_collection pin $pins {
    set pin_name [get_attribute $pin full_name]
    set slack [get_attribute $pin $delay_type -quiet]
    set direction [get_attribute $pin direction -quiet]
    set abutted_port [get_attribute [get_pins -of_objects [get_nets -of_objects $pin_name -quiet] -filter full_name!=$pin_name -quiet] full_name -quiet]
    lappend out "${pin_name},${slack},${direction},${abutted_port}"
  }
  return $out
}

# get ports that drived by pin_name
proc sio_mow_get_port_that_drived_by_pin {pin_name} {
  set pin [get_pins $pin_name]
  set par [get_partition_from_name [get_attribute $pin full_name]]
  set ret [list]
  set pins [get_pins -of [get_nets -of_objects [get_pins -of_objects [get_nets -top_net_of_hierarchical_group -segments -of [all_fanin -to $pin -flat]] -filter cell.is_hierarchical] -boundary_type both] -filter cell.is_hierarchical]
  foreach_in_collection p $pins {
    set pn [get_attribute $p full_name]
    if {[string equal -length [string length $par] $par $pn] && [llength [split $pn /]] == [expr [llength [split $par /]]+1] } {
      append_to_collection ret $p
    }
  }
  return $ret
}
# get ports that drive pin_name
proc sio_mow_get_port_that_drive_pin {pin_name} {
  set pin [get_pins $pin_name]
  set par [get_partition_from_name [get_attribute $pin full_name]]
  set ret [list]
  set pins [get_pins -of [get_nets -of_objects [get_pins -of_objects [get_nets -top_net_of_hierarchical_group -segments -of [all_fanout -from $pin -flat]] -filter cell.is_hierarchical] -boundary_type both] -filter cell.is_hierarchical]
  foreach_in_collection p $pins {
    set pn [get_attribute $p full_name]
    if {[string equal -length [string length $par] $par $pn] && [llength [split $pn /]] == [expr [llength [split $par /]]+1] } {
      append_to_collection ret $p
    }
  }
  return $ret
}
proc get_abutted_port {pin_name {partitions {}}} {
  if {[llength $partitions] == 0} {
    set partitions [get_partitions]
  }
  set abutted_port [get_attribute [get_pins -of_objects [get_nets -of_objects $pin_name -quiet] -filter full_name!=$pin_name -quiet] full_name -quiet]
  if {[get_partition_from_name $abutted_port $partitions] ne "/"} {
    return $abutted_port
  }
  set cur_par [get_partition_from_name [get_attribute [get_pins $pin_name] full_name]]
  array set tmp {}
  set pins [get_pins -of_objects [get_nets -of_objects [get_pins -of_objects [get_nets -of_objects $pin_name -quiet] -quiet] -boundary_type both -quiet] -quiet]
  foreach s [get_attribute $pins full_name -quiet] {
    lappend tmp([get_partition_from_name $s $partitions]) $s
  }
  if {[info exists tmp($cur_par)]} {
    unset tmp($cur_par)
  }
  foreach {key values} [array get tmp] {
    if {$key eq "/"} {
      continue
    }
    set abutted_port [lindex [lsort -command {apply {{a b} {expr {[string length $a] - [string length $b]}}}} $values] 0]
  }
  return $abutted_port
}
proc sio_mow_mbit_get_relevant {pin_name} {
  set sep "/"
  set pin_name_list [split $pin_name $sep]
  set p [lindex $pin_name_list end]
  if {![string equal -nocase -length 1 $p "d"] && ![string equal -nocase -length 1 $p "q"]  && ![string equal -nocase -length 1 $p "CN"]} {
    return $pin_name
  }
  if {[catch {
    set last_number [expr int([string range $p 1 [expr [string length $p] -1 ]])]
  }]} {
    return $pin_name
  }
  return [sio_mow_mbit_get_relevant_name $pin_name $last_number]
}

proc sio_mow_mbit_get_relevant_name {pin_name number {split_by "_mbit_"} {start_name "auto_vector_"}} {
  set length [string length $split_by]
  set pin_name_lower [string tolower $pin_name]
  set start [string last $start_name $pin_name_lower]
  if { $start == -1 } {
    return $pin_name
  }
  set i 1
  set ret [string range $pin_name 0 $start-2]
  while {$start >= 0} {
    set start [string first $split_by $pin_name_lower [expr $start +1]]
    if {$start == -1} {
      return $pin_name
    }
    set start [expr $start + $length]
    if {$i == $number} {
      set end [string first $split_by $pin_name_lower [expr $start +1]]
      if {$end == -1} {
        set end [string last "/" $pin_name_lower]
      }
      set ret "${ret}/[string range $pin_name $start [expr $end-1]]"
      return $ret
    }
    incr i
  }
  return $pin_name
}

proc sio_mow_fix_tip_data {input_file output_file} {
  printt "Start: [arginfo]"

  set target_res_det 100.0
  set in [open $input_file]
  set i 0
  array set header [list]
  set lines [list]
  while {[gets $in line] >= 0} {
    set id 0
    foreach ll [split $line ,] {
      set linel($id) $ll
      incr id
    }
    if {$i == 0} {
      foreach {id l} [array get linel] {
        set header($l) $id
      }
      if {![info exists header(res_reduce)]} {set header(res_reduce) [expr [lindex [lsort -stride 2 -index 1 -integer [array get header]] end] +1]}
      if {![info exists header(new_slack)]} {set header(new_slack) [expr [lindex [lsort -stride 2 -index 1 -integer [array get header]] end] +1]}
      if {![info exists header(new_delay)]} {set header(new_delay) [expr [lindex [lsort -stride 2 -index 1 -integer [array get header]] end] +1]}
      unset
    } else {
      if {$linel($header(is_cell_arc)) == 0 && $linel($header(res_det)) != "" && $linel($header(slack)) != "inf" && [expr ($linel($header(m13)) + $linel($header(m14))) > 50.0]} {
        set res_det [expr double($linel($header(res_det)))]
        set res_total [expr double($linel($header(res)))]
        if {[expr ${target_res_det} > ${res_det}]} {continue}
        set res_reduce [expr (($res_total - $res_det) + $target_res_det)/$res_total]
        set linel($header(res_reduce)) ${res_reduce}
        scale_parasitics -resistance_factor $res_reduce [get_nets -of_objects $linel($header(pin_from))]
        lappend lines [array get linel]
      }
    }
    incr i
  }
  close $in
  set lheader [lsort -stride 2 -index 1 -integer [array get header]]

  set out [open $output_file w]
  set line []
  foreach {l -} $lheader {
    lappend line $l
  }
  puts $out [join $line ,]
  unset linel
  foreach line $lines {
    array set linel $line
    set startpoint $linel($header(startpoint))
    set endpoint $linel($header(endpoint))
    set pin_from $linel($header(pin_from))
    set pin_to $linel($header(pin_to))
    set key "${startpoint},${endpoint}"
    if {![info exists paths($key)]} {
      set path [get_timing_path -from $startpoint -to $endpoint -through [list $pin_from $pin_to]]
      set paths($key) $path
    } else {
      #set path $paths($key)
    }
    set slack [get_attribute $path slack]
    set linel($header(new_slack)) $slack
    set arrival -1
    set linel($header(new_delay)) 0.0
    foreach_in_collection point [get_attribute $path points] {
      if {$arrival >= 0} {
        set delay [expr [get_attribute $point arrival] - $arrival]
        set linel($header(new_delay)) $delay
        break
      }
      if {[get_attribute $point object.full_name] eq $pin_from} {
        set arrival [get_attribute $point arrival]
      }
    }
    set ll [list]
    foreach {l id} $lheader {
      if {[catch {
        lappend ll $linel($id)
      }]} {
        puts $lheader
        puts [array get linel]
        return
      }
    }
    puts $out [join $ll ,]
  }
  close $out
  printt "End: [arginfo]"

}

proc sio_mow_get_tip_data {output_file} {
  printt "Start: [arginfo]"
  set tip_cells [get_cells -filter {base_name=~tip_cell_*} -hierarchical]
  array set done_hiers {}
  set id 0
  set header [list id id_path startpoint endpoint slack is_cell_arc pin_from cell_start pin_to cell_end delay distance]
  set lines [list]
  foreach_in_collection cell $tip_cells {
    set cell_name [get_attribute $cell full_name]
    if {[info exists done_hiers($cell_name)]} {
      continue
    }

    set path [get_timing_path -through $cell]
    set timing_points [get_attribute $path points]
    set last_arrival [get_attribute [index_collection $timing_points 0] arrival]
    set last_cell_full_name [get_attribute [index_collection $timing_points 0] object.cell.full_name]
    set last_pin_full_name [get_attribute [index_collection $timing_points 0] object.full_name]
    set all_cells [list]
    set llines [list]
    set slack [get_attribute $path slack]

    set last_x_coordinate [get_attribute [index_collection $timing_points 0] x_coordinate]
    set last_y_coordinate [get_attribute [index_collection $timing_points 0] y_coordinate]

    foreach_in_collection point [index_collection $timing_points 1 end] {
      set line ""
      set cell_local [get_attribute $point object.cell -quiet]
      set x_coordinate [get_attribute $point x_coordinate]
      set y_coordinate [get_attribute $point y_coordinate]
      if {$cell_local eq ""} {continue}
      set cell_ref_name [get_attribute $cell_local ref_name]
      set is_buf_inv [check_regexs_buffs_invs $cell_ref_name]
      set cell_full_name [get_attribute $cell_local full_name]
      set pin_full_name [get_attribute $point object.full_name]
      lappend all_cells $cell_full_name
      set arrival [get_attribute $point arrival]
      if {$is_buf_inv && [string match "*tip_*" [get_attribute $cell_local base_name]]} {
        set dist -
        catch {
          set dist [expr (abs($x_coordinate - $last_x_coordinate) + abs($y_coordinate - $last_y_coordinate))/1000]
        }
        set delay [expr $arrival - $last_arrival]
        set is_cell_arc [expr {$last_cell_full_name eq $cell_full_name}]
        append line "${slack},${is_cell_arc},${last_pin_full_name},${last_cell_ref_name},${pin_full_name},${cell_ref_name},${delay},${dist}"
        lappend llines $line
      }
      set last_cell_full_name $cell_full_name
      set last_arrival $arrival
      set last_pin_full_name $pin_full_name
      set last_x_coordinate $x_coordinate
      set last_y_coordinate $y_coordinate
      set last_cell_ref_name $cell_ref_name
    }

    if {[llength $llines]} { incr id }
    foreach c $all_cells {set done_hiers($c) 1}
    set id_path 0
    foreach line $llines {
      lappend lines "${id},[incr id_path],[get_attribute $path startpoint.full_name],[get_attribute $path endpoint.full_name],$line"
    }

  }
  set out [open $output_file w]
  puts $out [join $header ,]
  puts $out [join $lines "\n"]
  close $out
  printt "Done: [arginfo]"
}
proc lsum {l} {
  set sum 0
  foreach i $l {
    set sum [expr $sum + $i]
  }
  return $sum
}
proc lsum_tns {l} {
  set sum 0
  foreach i $l {
    set sum [expr $i<0?$sum + $i:$sum]
  }
  return $sum
}
proc sio_mow_port_tns_check_exceptions {paths} {
  set attr_exeptions [list dominant_exception startpoint_unconstrained_reason endpoint_unconstrained_reason]
  array set exeption {}
  foreach attr $attr_exeptions {
    set e [get_attribute -objects $paths -name $attr -quiet]
    if {$e ne ""} {foreach ee $e {set exeption($ee) 1}}
  }
  return [join [array names exeption] " "]
}

proc sio_mow_get_sio_buffer_data_from_paths {paths {check_name _sio_ovr_buffer}} {
  if {$paths eq "" || [sizeof_collection $paths] ==0} {
    return NA
  }
  set sio_buffs_delay 0.0
  set last_sio_ovr_buffer_arrival 0.0
  set count 0
  foreach_in_collection path $paths {
    foreach_in_collection point [get_attribute $path points] {
      if {[string match "*${check_name}/*" [get_attribute $point object.full_name]]} {
        if {$count_sio_ovr_buffer} {
          set sio_buffs_delay [expr $sio_buffs_delay + ([get_attribute $point arrival] - $last_sio_ovr_buffer_arrival )]
          set count_sio_ovr_buffer 0
          incr count
        } else {
          set count_sio_ovr_buffer 1
          set last_sio_ovr_buffer_arrival [get_attribute $point arrival]
        }
      } else {
        set count_sio_ovr_buffer 0
      }
    }
  }
  return [list $sio_buffs_delay $count]
}

proc sio_mow_get_start_end_through_pin_tp {pins} {
  set delay_type [sio_mow_get_delay_type]
  set pba_mode path
  set max_paths 100
  set tps [list]
  foreach_in_collection pin $pins {
    set tp [get_timing_paths -through $pin -delay_type $delay_type -pba_mode $pba_mode -max_paths $max_paths -start_end_pair -from mclk_* -to mclk_*]
    append_to_collection tps $tp
  }
  return $tps
}
proc sio_mow_port_tns {ports {output_file Port_Sum.report} {add_unconst_and_positive 0} {max_path 1000} {pba_mode none} {slack_lesser_than 0} {clock_to ""} } {
  printt "Start [arginfo]"
  suppress_message {UITE-629 UITE-487}
  set dfx_patterns_file ""
  if {[string match "PNC78*" [set ::env(PRODUCT_NAME)]]} {
    set dfx_patterns_file $::env(PNC_FCT_SCRIPTS)/dfx_patterns.json
  } elseif {[string match "GFCN2*" [set ::env(PRODUCT_NAME)]]} {
    set dfx_patterns_file $::env(GFC_FCT_SCRIPTS)/dfx_patterns.json
  }
  set dfx_patterns [list]
  if {[file exists $dfx_patterns_file]} {
    printt "Use dfx patterns file: $dfx_patterns_file"
    set dfx_patterns [exec python -c "import json;js = json.load(open('$dfx_patterns_file')) ; print(' '.join(js\['dfx_patterns'\]))"]
    printt "Dfx patterns: $dfx_patterns"
  }

  set sep ,
  set header [list port direction wns number_of_paths tns norm_wns ports partitions exceptions is_dfx startpoint_clock endpoint_clock sio_buffer_delay sio_pteco_delay port_to_seq_min port_to_seq_max uarch]
  if {[sizeof_collection ${ports}] eq ""} {
    set pins [get_pins ${ports}]
  } else {
    set pins $ports
  }
  set total [sizeof_collection $pins]
  set i 1
  printt "getting paths for $total ports"
  set lines [list]
  array set pins_arr {}
  set partitions [get_partitions]

  set exs ""
  set delay_type [sio_mow_get_delay_type]
  set count_ports 0
  set sio_logic_count_path_data [list]
  parallel_foreach_in_collection port $pins {
    set uarch ""
    set TIME_start [clock clicks -milliseconds]
    set port_name [get_attribute $port full_name]
    # printt "$port_name 1"
    if {$add_unconst_and_positive} {
      set paths [get_timing_paths -through $port -include_hierarchical_pins -pba_mode $pba_mode -delay_type $delay_type -slack_lesser_than $slack_lesser_than]
      set WNS [lindex [get_attribute $paths slack]  0]
    }
    # printt "$port_name 2"
    if {!$add_unconst_and_positive || ( [sizeof_collection $paths]>0 && $WNS ne "INFINITY" && [expr $WNS < 0] )} {
      if {$clock_to ne ""} {
        set paths [get_timing_paths -through $port -max_paths $max_path -to $clock_to -include_hierarchical_pins -pba_mode $pba_mode -slack_lesser_than $slack_lesser_than -delay_type $delay_type]
      } else {
        set paths [get_timing_paths -through $port -max_paths $max_path -include_hierarchical_pins -pba_mode $pba_mode -slack_lesser_than $slack_lesser_than -delay_type $delay_type]
      }
    }
    set startpoint_clock [get_attribute [add_to_collection -unique [get_attribute $paths startpoint_clock -quiet] [get_attribute $paths startpoint_clock]] full_name -quiet]
    set endpoint_clock [get_attribute [add_to_collection -unique [get_attribute $paths endpoint_clock -quiet] [get_attribute $paths endpoint_clock]] full_name -quiet]

    set exs [sio_mow_port_tns_check_exceptions $paths]

    set num_path [sizeof_collection $paths]
    # printt "$port_name 3"

    set dir [get_attribute $port direction]
    set is_dfx 0
    array unset ports_arr
    array unset pars_arr
    array set ports_arr [list]
    array set pars_arr [list]
    set WNS [sio_mow_get_attrbute_by_delay_type $port]
    set TNS 0
    set WNS_norm 0
    set port_in_bbox_min NA
    set port_in_bbox_max NA
    set port_in_bbox_list [list]
    if {$num_path == 0} {
      # printt "$port_name 4"

      set port_abutted [get_attribute [get_pins -of_objects [get_nets -of_objects $port_name -quiet] -filter full_name!=$port_name -quiet] full_name -quiet]
      set ports_arr($port_name) 1
      set pars_arr([get_partition_from_name $port_name $partitions]) 1
      if {$port_abutted ne "" } {
        set ports_arr($port_abutted) 1
        set pars_arr([get_partition_from_name $port_abutted $partitions]) 1
      }
    } else {
      # printt "$port_name 5"

      set WNS [lindex [ get_attribute $paths slack]  0]
      set TNS [lsum_tns [ get_attribute $paths slack]]
      if {[sizeof_collection [get_attribute [index_collection $paths 0] endpoint_clock -quiet]] > 0} {
        set normalized_slack [lsearch -inline -all -not -exact [get_attribute $paths normalized_slack] "UNINIT"]
        if {[llength $normalized_slack] == 0} {
          set wns_normalized_slack 0
        } else {
          set wns_normalized_slack [lindex [lsort -r $normalized_slack ] 0 ]
        }
        set WNS_norm [expr $wns_normalized_slack * [get_attribute [get_attribute [index_collection $paths 0] endpoint_clock -quiet] period] ]
      } else {
        set WNS_norm ""
      }
      # printt "$port_name 6"
      set uarch [check_path_is_uarch_paths $paths]
      foreach_in_collection path $paths {
        set pars {}
        set ports {}

        lassign [get_ports_from_points [get_attribute $path points] 1 $partitions] pars ports
        catch {
          lappend port_in_bbox_list [check_port_location_outside_bbox_tp $path $port]
        }
        foreach par $pars {
          set pars_arr($par) 1
        }
        foreach dfx_pattern $dfx_patterns {
          if {[regexp ${dfx_pattern} [get_attribute $path startpoint.full_name]] || [regexp ${dfx_pattern} [get_attribute $path endpoint.full_name]]} {
            incr is_dfx 1
            break
          }
        }

        foreach p $ports {
          set rr [list]
          foreach pp $p {
            lappend rr [compress_pin_name $pp]
          }
          set key [join $rr " "]
          set ports_arr($key) 1
        }
      }
      if {[sizeof_collection $paths]} {
        set is_dfx [expr double($is_dfx)/[sizeof_collection $paths]]
      }
    }
    # printt "$port_name 7"
    set portsl [join [array names ports_arr] "|"]
    set parsl [join [array names pars_arr] " "]
    lassign [sio_mow_get_sio_buffer_data_from_paths $paths] sio_buffer_delay sio_buffer_count
    lassign [sio_mow_get_sio_buffer_data_from_paths $paths PTECO_HOLD_*] sio_pteco_delay sio_pteco_count
    catch {
      set port_in_bbox_min [tcl::mathfunc::min {*}$port_in_bbox_list]
      set port_in_bbox_max [tcl::mathfunc::max {*}$port_in_bbox_list]
    }
    set TIME_taken [expr ([clock clicks -milliseconds] - $TIME_start)*0.001]
    # printt "$port_name 8"
    if {$num_path > 0} {
      set lgccnt [lindex [sio_logic_count_path [index_collection $paths 0] 0 0 1] 0]
    }
    post_eval {
      #start post_eval
      # printt "$port_name 9"

      lappend lines [list $port_name $dir $WNS $num_path $TNS ${WNS_norm} $portsl $parsl $exs $is_dfx $startpoint_clock $endpoint_clock $sio_buffer_delay $sio_pteco_delay $port_in_bbox_min $port_in_bbox_max $uarch]
      if {$num_path > 0} {
        lappend sio_logic_count_path_data $lgccnt
      }
      printt "Port runtime ([incr count_ports]/${total}): '${port_name}' [expr $TIME_taken] seconds"
      # printt "$port_name 10"
      #end post_eval
    }
  }
  puts "[llength $sio_logic_count_path_data]"
  if {[llength $sio_logic_count_path_data] > 0} {
    if {$output_file ne ""} {
      set out [open ${output_file}.sio_logic_count_path.csv w]
      set header_sio_logic_count_path [sio_logic_count_path {} 1 1 1]
      puts $out [lindex $header_sio_logic_count_path 0]
      set count 0
      foreach line $sio_logic_count_path_data {
        puts $out "[incr count],$line"
      }
      close $out
      catch {
        exec /nfs/site/disks/ayarokh_wa/tools/sio_mow/make_path_worst_analysis.py -i ${output_file}.sio_logic_count_path.csv -o [file dirname ${output_file}]/path.worst_analysis.xlsx
      }
    }
  }
  unsuppress_message {UITE-629 UITE-487}
  printt "Start write [arginfo]"
  if {$output_file ne ""} {
    set out [open $output_file w]
    puts $out [join $header $sep]
    foreach l $lines {
      puts $out [join $l $sep]
    }
    close $out
  } else {
    return $lines
  }
}
proc sio_vec_sio_logic_count_path_data_one_pin {pin} {
  set pin [get_pins $pin -quiet]
  if {$pin eq ""} {
    return
  }
  set sio_logic_count_path_data [list]
  set pin_name [get_attribute $pin full_name]
  set direction [get_attribute $pin direction]
  if {$direction eq "out"} {
    set paths [sio_all_fanin_fanout_through_port -th $pin -fanin_fanout_all fanin_only]
  } else {
    set paths [sio_all_fanin_fanout_through_port -th $pin -fanin_fanout_all fanout_only]
  }

  set num_path [sizeof_collection $paths]
  if {$num_path == 0} {
    return
  }
  if {[catch {
    foreach_in_collection path $paths {
      array set check_spec [sio_mow_check_spec $path 0 0]
      set data_spec $check_spec(data)
      set done_check_spec 0
      foreach lspecl $data_spec {
        foreach l $lspecl {
          if {[lindex $l 0] eq $pin_name || [lindex $l 1] eq $pin_name} {
            set lgccnt [lindex [sio_logic_count_path $path 0 0 1] 0],[join [lrange $l 0 end-1] ,]
            set done_check_spec 1
            break
          }
        }
        if {$done_check_spec} {
          break
        }
      }
      if {!$done_check_spec} {
        set lgccnt [lindex [sio_logic_count_path $path 0 0 1] 0],NO_CHECK_SPEC_DATA
      }
      lappend sio_logic_count_path_data $lgccnt
    }
  } err]} {
    printt "Error in pin $pin_name"
    printt "$err"
  }
  return $sio_logic_count_path_data
}
proc sio_vec_sio_logic_count_path_data_rob_mob {} {
  set pins [get_pins {icore0/par_meu/*rortldincm904h* icore0/par_pmh/*rortldincm904h* icore0/par_meu/*ronukeallm907h* icore0/par_ooo_int/*rortmempwrenm902h* icore0/par_ooo_int/*roearlynukelm905h* icore0/par_meu/*roearlynukem905h* icore0/par_meu/*rortatretst_m903h* icore0/par_meu/*rortstincm903h* icore0/par_meu/*rortatretld_m903h* icore0/par_ooo_int/*moclearearlyvm902h* icore0/par_ooo_vec/*rsmoclearspecstallm901h* icore0/par_pmh/*rortmempwrenm903h* icore0/par_ooo_int/*rortldincm903h* icore0/par_ooo_int/*romemrtptrvm903h* icore0/par_meu/*romemrtptrvm904h* icore0/par_ooo_int/*rortptrnowrapm902h** icore0/par_meu/*rortptrnowrapm903h** icore0/par_ooo_vec/*mosnoopexternalstallm901h* }]
  printt "Start [arginfo]"
  # set outfile ~/tmp/sio_vec_sio_logic_count_path_data_800h.csv
  # sio_vec_sio_logic_count_path_data $outfile $pins
  set outfile ~/tmp/sio_all_start_end_pair_through_port_report_rob_mob.csv
  sio_all_start_end_pair_through_port_report $outfile $pins path
  printt "Done [arginfo]"
}


proc sio_vec_sio_logic_count_path_data_800h {} {
  set pins [get_pins {icore0/par_ooo_vec/*monofirstbpfromldm800h* icore0/par_ooo_vec/*mopdstprftypem800h* icore0/par_ooo_vec/*rsldgathercomppdstm801h* icore0/par_ooo_vec/*rspwrupldm801h* icore0/par_ooo_vec/*RSLDCamcRdyEuM300H*reg** icore0/par_ooo_vec/*rsvecwbpdstldm800h* icore0/par_ooo_vec/*mowbvldm800h*}]
  printt "Start [arginfo]"
  # set outfile ~/tmp/sio_vec_sio_logic_count_path_data_800h.csv
  # sio_vec_sio_logic_count_path_data $outfile $pins
  set outfile ~/tmp/sio_all_start_end_pair_through_port_report_800h.csv
  sio_all_start_end_pair_through_port_report $outfile $pins path
  printt "Done [arginfo]"
}

proc sio_vec_sio_logic_count_path_data {outfile {pins icore0/par_ooo_vec/*}} {
  printt "Start [arginfo]"
  set pins [get_pins $pins]
  # set pins [get_pins icore0/par_ooo_vec/rs*301h*]
  # set pins [get_pins icore0/par_ooo_vec/rsvecpsrcm301h_*__*__*_*_[*]]
  array set sio_logic_count_path_data [list]
  foreach_in_collection pin $pins {
    set data [sio_vec_sio_logic_count_path_data_one_pin $pin]
    if {[llength $data] > 0} {
      set pin_name [get_attribute $pin full_name]
      set sio_logic_count_path_data($pin_name) $data
    }
  }
  set out [open $outfile w]
  set header_sio_logic_count_path [sio_logic_count_path {} 1 0 1],[join {startpoint endpoint spec_port calculated_slack delay clk_skew sio_buffer_delay latches_count ebbs_count logic_count inv_buffs_count manh_dist delay_per100um tot_dist rc_delay inv/buff_dealy logic_cell_delay ebb_delay} ,]
  puts $out pin,direction,count,[lindex $header_sio_logic_count_path 0]
  set count 0
  foreach pin_name [array names sio_logic_count_path_data] {
    foreach line $sio_logic_count_path_data($pin_name) {
      puts $out "${pin_name},[get_attribute [get_pins $pin_name] direction],[incr count],$line"
    }
  }
  close $out
  printt "End [arginfo]"
}

proc compress_pin_names {pin_names} {
  array set pins_done_arr {}
  array set pin_name_ret {}
  set ret ""
  foreach pin_name $pin_names {
    set pin_name_ret([compress_pin_name $pin_name]) 1
  }
  return [array names pin_name_ret]
}
proc compress_pin_name {pin_name {pins_done_arr_depricated ""}} {
  global sio_mow_compress_pin_name_cache
  if {[info exists sio_mow_compress_pin_name_cache($pin_name)]} {
    return $sio_mow_compress_pin_name_cache($pin_name)
  }
  set compressed ""
  set r [list]
  foreach p [split $pin_name _] {
    if {$p ne "" && [string is integer $p]} {
      lappend r *
    } else {
      lappend r $p
    }
  }
  set pin_name_ret [regsub  -all  {\[\d+\]} [join $r _] {[*]}]
  set sio_mow_compress_pin_name_cache($pin_name) $pin_name_ret
  return $pin_name_ret
}

proc sio_mow_get_normalized_slack {tp} {
  set normalized_slack [get_attribute $tp normalized_slack_no_close_edge_adjustment -quiet]
  if {$normalized_slack eq ""} {
    set normalized_slack [get_attribute $tp normalized_slack -quiet]
  }
  return $normalized_slack
}
proc sio_mow_get_pin_spec {pin {clock ""}} {
  set spec [sio_mow_get_pin_spec_any $pin $clock bu_spec]
  if {$spec eq "" || $spec == 0} {
    set spec [sio_mow_get_pin_spec_any $pin $clock spec_details]
  }
  return $spec
}
proc sio_mow_get_pin_spec_any {pin {clock ""} {spec_attr spec_details}} {
  set ret ""
  set a [get_attribute $pin $spec_attr -q]
  if {$clock eq "" || [llength $a] < 2} {
    set ret [lindex [lindex $a 0] 0]
  } else {
    foreach d $a {
      lassign $d spec spec_clock
      if {$spec_clock eq $clock} {
        return $spec
      }
    }
  }
  return [expr {$ret eq ""?0:$ret}]
}

proc sio_mow_check_spec_get_realted_arrival_to_port {points port_i} {
  set i $port_i
  set point [index_collection $points $i]
  set last_arrival [get_attribute $point arrival]
  set p1_x [get_attribute $point x_coordinate]
  set p1_y [get_attribute $point y_coordinate]
  set s_x [get_attribute $point x_coordinate]
  set s_y [get_attribute $point y_coordinate]
  set start_pin ""
  set end_pin ""
  while {$i >= 0} {
    set point [index_collection $points $i]
    set arrival [get_attribute $point arrival]
    if {$arrival != $last_arrival} {
      break
    }
    set start_pin [get_attribute $point object.full_name]
    set s_x [get_attribute $point x_coordinate]
    set s_y [get_attribute $point y_coordinate]
    incr i -1
  }
  set i $port_i
  set p2_x UNINIT
  set p2_y UNINIT
  if {[sizeof_collection $points] > $i} {
    set point [index_collection $points $port_i]
    set p2_x [get_attribute $point x_coordinate]
    set p2_y [get_attribute $point y_coordinate]

  }
  set e_x UNINIT
  set e_y UNINIT
  while {$i < [sizeof_collection $points]} {
    set point [index_collection $points $i]
    set arrival [get_attribute $point arrival]
    set e_x [get_attribute $point x_coordinate]
    set e_y [get_attribute $point y_coordinate]
    if {$arrival != $last_arrival} {
      set end_pin [get_attribute $point object.full_name]
      break
    }
    incr i
  }
  set rel [get_realted_percent2 $s_x $s_y $p1_x $p1_y $p2_x $p2_y $e_x $e_y]
  set arr_to [expr ${rel}*($arrival-$last_arrival)]
  return [list $rel $arr_to $start_pin $end_pin [expr ($arrival-$last_arrival) - $arr_to]]
}

proc sio_mow_check_spec_get_ft_spec {pin} {
  set spec ""
  foreach n [list FT_DLY_USER_OVR FT_DLY_CALC] {
    set spec [lindex [lindex [get_attribute [get_pins $pin] $n -quiet] 0] 1]
    if {$spec ne ""} {break}
  }
  if {$spec eq ""} {set spec 0}
  return $spec
}

proc sio_mow_check_spec_pin_is_latch {pin} {
  set cell [get_attribute $pin cell -quiet]
  if {[get_attribute $pin is_hierarchical -quiet] ne "" && ![get_attribute $pin is_hierarchical -quiet] && $cell ne ""} {
    return [expr ([get_attribute -quiet $cell is_negative_level_sensitive] || [get_attribute -quiet $cell is_positive_level_sensitive]) && ![get_attribute -quiet $cell is_black_box]]
  }
  return 0
}

proc sio_mow_check_spec_csv {tps} {
  array set data [sio_mow_check_spec $tps 0 {}]
  set ret [list]
  lappend ret [join $data(header) ,]
  foreach dd $data(data) {
    foreach d $dd {lappend ret [join $d ,]}
  }
  return [join $ret "\n"]
}
#get timing path
proc sio_mow_check_spec_calculate_dist_from_coords {coordinates} {
  set tot_dist NA
  if {[llength $coordinates] > 1} {
    set _dist 0
    lassign [split [lindex $coordinates 0] ,] prev_coord_x prev_coord_y
    foreach coord $coordinates {
      lassign [split $coord ,] coord_x coord_y
      set _dist [expr $_dist + abs($prev_coord_x - $coord_x) + abs($prev_coord_y - $coord_y)]
      set prev_coord_x $coord_x
      set prev_coord_y $coord_y
    }
    set tot_dist [expr double($_dist)/1000]
  }
  return $tot_dist
}
proc sio_mow_check_spec {tps {print 0} {header {}}} {
  set _sio_ovr_buffer_string _sio_ovr_buffer
  set ebbs [get_ebb_names]
  set partitions [get_partitions]
  array set ebbs_arr {}
  foreach ebb $ebbs {
    set ebbs_arr($ebb) 1
  }

  # sio_manh_dist
  # get_realted_percent
  set ret [list]
  foreach_in_collection tp $tps {
    set ret_path [list]
    set coordinates [list]
    set sio_buffs_delay 0.0
    set last_sio_ovr_buffer_arrival 0.0
    set points [get_attribute $tp points]

    set startpoint [get_attribute $tp startpoint.full_name]
    set last_par [get_partition_from_name $startpoint]
    set start_arrival [get_attribute [index_collection $points 0] arrival]
    set cells_count_init [list inv_buffs_count 0 latches_count 0 ebbs_count 0 ebbs_as_latches_count 0 logic_count 0]
    array set cells_counter $cells_count_init

    set i 0
    set skip 0
    set header [list]
    foreach_in_collection point $points {
      if {[get_attribute $point x_coordinate -quiet] ne "" && [get_attribute $point x_coordinate -quiet] ne "UNINIT"} {
        lappend coordinates [get_attribute $point x_coordinate -quiet],[get_attribute $point y_coordinate -quiet]
        # echo [get_partition_from_name [get_attribute $point object.full_name] $partitions] $coordinates
      }
      if {$skip} {
        incr skip -1
        incr i 1
        continue
      }
      set cell [get_attribute $point object.cell -quiet]
      set ref_name [get_attribute $cell ref_name -quiet]
      set pin [get_attribute $point object]
      set par [get_partition_from_name [get_attribute $pin full_name] $partitions]
      set arrival [get_attribute $point arrival]
      if {$cell eq ""} {continue}
      if {[get_attribute $cell full_name] != [get_attribute [index_collection $points 0] object.cell.full_name] && [get_attribute $cell full_name] != [get_attribute [index_collection $points end] object.cell.full_name]} {
        set is_latch [sio_mow_check_spec_pin_is_latch $pin]
        incr cells_counter(latches_count) $is_latch
        if {!$is_latch && [check_regexs_buffs_invs $ref_name]} {
          incr cells_counter(inv_buffs_count)
        } elseif {[get_attribute $cell is_black_box -quiet] ne "" && [get_attribute $cell is_black_box -quiet] && [info exists ebbs_arr($ref_name)]} {
          incr cells_counter(ebbs_count)
          incr cells_counter(ebbs_as_latches_count) $is_latch
        } elseif {![get_attribute $cell is_hierarchical -quiet] && !$is_latch} {
          incr cells_counter(logic_count)
        }
      }
      # check port
      set is_port [expr {$par ne $last_par}]
      if {$is_port} {
        # set rcv_spec [sio_mow_get_pin_spec $last_pin]
        # set drv_spec [sio_mow_get_pin_spec $pin]
        lassign [sio_mow_check_spec_get_realted_arrival_to_port $points $i] related_perc arrival_related pin_drv pin_rcv
        set par [get_partition_from_name $pin_rcv]
        set j $i
        set skip 0
        set endpoint [get_attribute [index_collection $points [expr $i - 1]] object.full_name]

        set arrival [expr $arrival + $arrival_related]
        set delay [expr $arrival - $start_arrival]
        set tot_dist [sio_mow_check_spec_calculate_dist_from_coords [lrange $coordinates 0 end-1]]
        lappend ret_path [list $startpoint $endpoint $delay $sio_buffs_delay [expr $cells_counter(latches_count)/2] [expr $cells_counter(ebbs_count)/2] [expr $cells_counter(inv_buffs_count)/2] [expr $cells_counter(ebbs_as_latches_count)/2] [expr $cells_counter(logic_count)/2] ${tot_dist}]
        set start_arrival $arrival
        array set cells_counter $cells_count_init

        set sio_ovr_buffer 0
        set sio_buffs_delay 0.0
        set last_sio_ovr_buffer_arrival 0.0
        set coordinates [lindex $coordinates end]
        while {$j} {
          set startpoint [get_attribute [index_collection $points $j] object.full_name]
          if {[get_partition_from_name $startpoint] eq $par} {
            break
          }
          incr j
          incr skip
        }
      }
      # check sio buffers
      if {[string match "*${_sio_ovr_buffer_string}/*" [get_attribute $pin full_name]]} {
        if {$sio_ovr_buffer} {
          set sio_ovr_buffer 0
          set sio_buffs_delay [expr $sio_buffs_delay + ($arrival - $last_sio_ovr_buffer_arrival)]
        } else {
          set sio_ovr_buffer 1
          set last_sio_ovr_buffer_arrival $arrival
        }
      } else {
        set sio_ovr_buffer 0
      }
      set last_par $par
      incr i
    }
    set tot_dist [sio_mow_check_spec_calculate_dist_from_coords $coordinates]
    lappend ret_path [list $startpoint [get_attribute $tp endpoint.full_name] [expr [get_attribute [index_collection $points end] arrival] - $start_arrival] $sio_buffs_delay [expr $cells_counter(latches_count)/2] [expr $cells_counter(ebbs_count)/2] [expr $cells_counter(inv_buffs_count)/2] [expr $cells_counter(ebbs_as_latches_count)/2] [expr $cells_counter(logic_count)/2] $tot_dist]
    array set r [_sio_mow_check_spec_add_spec $tp $ret_path $header]
    lappend ret $r(data)
    set header $r(header)
  }
  if {$print} {
    foreach rr $ret {
      printColumnarLines [concat [list $header] $rr]
    }
  } else {
    return [list data $ret header $header]
  }
}
proc printColumnarLines {lines} {
  foreach fields $lines {
    set column 0
    foreach field $fields {
      set w [string length $field]
      if {![info exist width($column)] || $width($column) < $w} {
        set width($column) $w
      }
      incr column
    }
  }
  foreach fields $lines {
    set column 0
    foreach field $fields {
      puts -nonewline [format "%-*s " $width($column) $field]
      incr column
    }
    puts ""; # Just the newline please
  }
}
proc _sio_mow_check_spec_add_spec {tp ret_path {header {}}} {
  set clk_target [sio_mow_get_clk_target_get]
  if {[llength $header] == 0} {
    set header [list startpoint endpoint spec_port calculated_slack delay clk_skew sio_buffer_delay latches_count ebbs_count logic_count inv_buffs_count manh_dist delay_per100um tot_dist rc_delay inv/buff_dealy logic_cell_delay ebb_delay calculated_slack_tooltip]
  }
  set delay_per_type [sio_mow_get_rc_cell_delay_per_par [get_attribute $tp points]]
  set slack [get_attribute $tp slack]
  set normalized_slack [sio_mow_get_normalized_slack $tp]
  set time_lent_to_startpoint [get_attribute $tp time_lent_to_startpoint]
  set time_borrowed_from_endpoint [get_attribute $tp time_borrowed_from_endpoint]
  set time_borrowed_from_endpoint 0
  set startpoint_clock_latency [get_attribute $tp startpoint_clock_latency]
  set startpoint_clock_open_edge_value [get_attribute $tp startpoint_clock_open_edge_value -quiet]
  if {$startpoint_clock_open_edge_value eq ""} {set startpoint_clock_open_edge_value 0}
  set statistical_adjustment [get_attribute $tp statistical_adjustment -quiet]
  set cycle_time [get_attribute $tp endpoint_clock.period -quiet]
  if {$cycle_time eq ""} {set cycle_time 0}

  set endpoint_setup_time_value [get_attribute $tp endpoint_setup_time_value -quiet]
  if {$endpoint_setup_time_value eq ""} {set endpoint_setup_time_value 0}

  set endpoint_clock_latency [get_attribute $tp endpoint_clock_latency -quiet]
  if {$endpoint_clock_latency eq ""} {set endpoint_clock_latency 0}
  set endpoint_clock_close_edge_value [get_attribute $tp endpoint_clock_close_edge_value -quiet]
  if {$endpoint_clock_close_edge_value eq ""} {set endpoint_clock_close_edge_value 0}
  set start_arrival [get_attribute [index_collection [get_attribute $tp points] 0] arrival]
  set path_cycles 0
  if { [get_attribute -quiet $tp normalized_slack ]!=0} {
    catch {set path_cycles [expr round($slack / $normalized_slack)]}
  }
  set can_check_slack 2
  foreach r $ret_path {
    lassign $r startpoint endpoint delay sio_buffer_delay latches_count ebbs_count inv_buffs_count ebbs_as_latches_count logic_count tot_dist
    if {$ebbs_as_latches_count} {
      incr can_check_slack -1
    }
  }
  set ret [list]
  set i 0
  foreach r $ret_path {
    lassign $r startpoint endpoint delay sio_buffer_delay latches_count ebbs_count inv_buffs_count ebbs_as_latches_count logic_count tot_dist
    set startpoint_col [index_collection [filter_collection [get_attribute $tp points.object] full_name==$startpoint] 0]
    set endpoint_col [index_collection [filter_collection [get_attribute $tp points.object] full_name==$endpoint] 0]
    array set delay_per_type_arr [lassign [lindex $delay_per_type $i] - - -]
    foreach {a b} [array get delay_per_type_arr] {
      set $a $b
    }
    set manh_dist NA
    set delay_per100um NA
    catch {
      set manh_dist [expr [sio_manh_dist $startpoint_col $endpoint_col]/1000]
      set delay_per100um [expr double(round(10000*$delay/$manh_dist))/100]
    }
    if {$i == [expr [llength $ret_path]-1]} {
      # don't use clock for finfing spec after added bu_spec 21/08/2024
      # set spec_port [sio_mow_get_pin_spec $startpoint_col [get_attribute $tp endpoint_clock.full_name -quiet]]
      set spec_port [sio_mow_get_pin_spec $startpoint_col]
      set delay [expr $delay + $endpoint_setup_time_value]
      set clk_skew [expr $endpoint_clock_latency - $clk_target]
      set calculated_slack_tooltip "spec_port($spec_port) - ( clk_target($clk_target) - endpoint_clock_latency($endpoint_clock_latency) ) \
        - ( delay($delay) - ( latches_count($latches_count) * cycle_time($cycle_time)/2 ) + time_borrowed_from_endpoint($time_borrowed_from_endpoint) + sio_buffer_delay($sio_buffer_delay))"
      set calculated_slack [expr $spec_port - ( $clk_target - $endpoint_clock_latency ) \
        - ( $delay - ( $latches_count * $cycle_time/2 ) + $time_borrowed_from_endpoint + $sio_buffer_delay)]
    } elseif {$i == 0} {
      set clk_skew [expr $startpoint_clock_latency - $clk_target]
      # don't use clock for finfing spec after added bu_spec 21/08/2024
      # set spec_port [sio_mow_get_pin_spec $endpoint_col [get_attribute $tp startpoint_clock.full_name]]
      set spec_port [sio_mow_get_pin_spec $endpoint_col]
      set calculated_slack_tooltip "latches_count($latches_count) * cycle_time($cycle_time)/2 + spec_port($spec_port) - (startpoint_clock_latency($startpoint_clock_latency) -\
        clk_target($clk_target) + startpoint_clock_open_edge_value($startpoint_clock_open_edge_value)) - delay($delay) - time_lent_to_startpoint($time_lent_to_startpoint) + start_arrival($start_arrival) + startpoint_clock_open_edge_value($startpoint_clock_open_edge_value) + sio_buffer_delay($sio_buffer_delay)"
      set calculated_slack [expr $latches_count * $cycle_time/2 + $spec_port - ($startpoint_clock_latency-$clk_target+$startpoint_clock_open_edge_value) - $delay - $time_lent_to_startpoint + $start_arrival + $startpoint_clock_open_edge_value + $sio_buffer_delay]
    } else {
      set clk_skew 0
      set spec_port [sio_mow_check_spec_get_ft_spec $startpoint_col]
      set calculated_slack_tooltip "ft_spec_port($spec_port) - delay($delay) - sio_buffer_delay($sio_buffer_delay)"
      set calculated_slack [expr $spec_port - $delay - $sio_buffer_delay]
    }
    if {!$can_check_slack} {
      set calculated_slack "#EBBs > 1 in par"
    }
    set rrr [list]
    foreach head $header {
      lappend rrr [set $head]
    }
    set rr $rrr
    incr i
    # echo $rr
    lappend ret $rr
  }
  return [list data $ret header $header]
}
proc get_to_and_from_from_tp {tp} {
  set delay_type [sio_mow_get_delay_type]
  array set ret [list prev [list] next [list]]
  set points [get_attribute $tp points]
  set startpoint [get_attribute $tp startpoint]
  set endpoint [get_attribute $tp endpoint]
  if {[get_attribute $startpoint object_class] ne "port"} {
    if {[get_attribute $startpoint direction] == "in" && ![get_attribute $startpoint is_clock_pin] && [get_attribute $startpoint is_data_pin] } {
      set ret(prev) [list args [list -to [get_attribute $startpoint full_name]] object $startpoint max_slack [sio_mow_get_attrbute_by_delay_type $startpoint]]
    } elseif {[get_attribute $startpoint direction] == "out" && [get_attribute $startpoint is_data_pin]} {
      set to_pin [get_to_and_from_from_tp_get_arc_to $startpoint]
      set ret(prev) [list args [list -to [get_attribute $to_pin full_name]] object $to_pin max_slack [sio_mow_get_attrbute_by_delay_type $to_pin]]
    } else {
      set to_pin [get_to_and_from_from_tp_get_arc_to [index_collection [get_attribute $tp points.object] 1]]
      set ret(prev) [list args [list -to [get_attribute $to_pin full_name]] object $to_pin max_slack [sio_mow_get_attrbute_by_delay_type $to_pin]]
    }
  }
  if {[get_attribute $endpoint object_class] ne "port"} {
    if {[get_attribute $endpoint direction] == "in" && ![get_attribute $endpoint is_clock_pin] && [get_attribute $endpoint is_data_pin] } {
      set through_pin [get_to_and_from_from_tp_get_arc_from $endpoint]
      set allfanins [all_fanin -startpoints_only -to $through_pin -quiet]
      if {[sizeof_collection $allfanins] == 0} {
        set ret(next) [list args [list -from [get_attribute $through_pin full_name]] object $through_pin max_slack [sio_mow_get_attrbute_by_delay_type $through_pin]]
      } else {
        foreach_in_collection aa $allfanins {
          if {[get_attribute $aa cell.full_name] == [get_attribute $through_pin cell.full_name]} {
            set ret(next) [list args [list -from [get_attribute $aa full_name] -through [get_attribute $through_pin full_name]] object $through_pin max_slack [sio_mow_get_attrbute_by_delay_type $through_pin]]
            break
          }
        }
      }
    }
  }
  return [array get ret]
}
proc get_to_and_from_from_tp_get_arc_to {pin} {
  if {[get_attribute $pin object_class] ne "pin"} {
    return ""
  }
  set pins [get_pins -of_objects [get_cells -of_objects $pin] -filter !is_clock_pin&&direction=~in*&&is_data_pin&&!disable_timing&&!is_async_pin&&!is_clear_pin -quiet]
  if {[sizeof_collection $pins] == 1} {
    return $pins
  }
  if {[sizeof_collection $pins] == 0} {
    return {}
  }
  #probably mbit ???
  if {[string equal -length 1 [get_attribute $pin lib_pin_name] "o"] || [string equal -length 1 [string toupper [get_attribute $pin lib_pin_name]] "Q"]} {
    # PNC mbit
    if {[llength [lsearch -ascii -exact -all [split [string tolower [get_attribute $pin full_name]] _] mbit]] > 1} {
      return [get_pins $pins -filter lib_pin_name==[string map {o d Q D q d} [get_attribute $pin lib_pin_name]]]
    }

  }
  if {[string equal [get_attribute $pin lib_pin_name] "o"] && [sizeof_collection [get_pins $pins -filter lib_pin_name==d -quiet]] == 1} {
    return [get_pins $pins -filter lib_pin_name==d]
  }
  if {[string equal [string toupper [get_attribute $pin lib_pin_name -quiet]] "Q"] && [sizeof_collection [get_pins $pins -filter lib_pin_name==D -quiet]] == 1} {
    return [get_pins $pins -filter lib_pin_name==D -quiet]
  }
  if {[string equal [string toupper [get_attribute $pin lib_pin_name]] "QN"] && [sizeof_collection  [get_pins $pins -filter lib_pin_name==D -quiet]] == 1} {
    return [get_pins $pins -filter lib_pin_name==D -quiet]
  }
  set pins_to_check [list]
  if {[sizeof_collection $pins] > 0} {
    set arcs [get_timing_arcs -to $pin -from $pins -filter {is_cellarc&&!is_disabled}]
    if {[sizeof_collection $arcs] != 0} {
      set pins_to_check [get_attribute $arcs from_pin ]
    }
  } else {
    if {[string equal -length 1 [get_attribute $pin lib_pin_name] "o"] || [string equal -length 1 [string toupper [get_attribute $pin lib_pin_name]] "Q"]} {
      set pins [get_pins -of_objects [get_cells -of_objects $pin] -filter direction=~in&&!disable_timing&&!is_async_pin&&!is_clear_pin -quiet]
      # PNC mbit
      if {[llength [lsearch -ascii -exact -all [split [string tolower [get_attribute $pin full_name]] _] mbit]] > 1} {
        set pins_to_check [get_pins $pins -filter lib_pin_name==[string map {o d Q D} [get_attribute $pin lib_pin_name]] -quiet]
      }
    }
  }
  if {[sizeof_collection $pins_to_check] == 1} {
    return $pins_to_check
  }
  return [index_collection [sort_collection $pins_to_check max_slack] 0]
}
proc get_to_and_from_from_tp_get_arc_from {pin} {
  if {[get_attribute $pin object_class] == "pin"} {
    set pin [get_pins $pin -quiet]
  } else {
    return ""
  }
  set pins [get_pins -of_objects [get_cells -of_objects $pin] -filter !is_clock_pin&&direction=~*out&&!disable_timing&&!is_async_pin&&!is_clear_pin  -quiet]
  if {[sizeof_collection $pins] == 1} {
    return $pins
  }
  if {[sizeof_collection $pins] == 0} {
    return {}
  }
  #probably mbit ???
  set pins_to_check [list]
  if {[string equal -nocase -length 1 [get_attribute $pin lib_pin_name] "d"] || [string equal -nocase -length 2 [get_attribute $pin lib_pin_name] "CN"]} {
    if {[llength [lsearch -ascii -exact -all [split [string tolower [get_attribute $pin full_name]] _] mbit]] > 1} {
      set r [get_pins $pins -filter lib_pin_name==[string map {d q d o D Q CN Q} [get_attribute $pin lib_pin_name]] -quiet]
      if {[sizeof_collection $r] > 0} {
        return $r
      }
      return [get_pins $pins -filter lib_pin_name==[string map {d q d o D Q CN Q C Q}  [get_attribute $pin lib_pin_name]] -quiet]
    }
  }
  if {[string equal [get_attribute $pin lib_pin_name] "d"] && [sizeof_collection [get_pins $pins -filter lib_pin_name==o -quiet]]} {
    return [get_pins $pins -filter lib_pin_name==o -quiet]
  }
  if {[string equal [get_attribute $pin lib_pin_name] "d"] && [sizeof_collection [get_pins $pins -filter lib_pin_name==q -quiet]]} {
    return [get_pins $pins -filter lib_pin_name==q -quiet]
  }
  if {[string equal [get_attribute $pin lib_pin_name] "D"] && [sizeof_collection [get_pins $pins -filter lib_pin_name==Q -quiet]]} {
    return [get_pins $pins -filter lib_pin_name==Q -quiet]
  }
  set arcs [get_timing_arcs -from $pin -to $pins -filter {is_cellarc&&!is_disabled}]
  if {[sizeof_collection $arcs] != 0} {
    set pins_to_check [get_attribute $arcs to_pin]
  } else {
    return [get_pins $pins -filter {lib_pin_name==o || lib_pin_name==QN  || lib_pin_name==Q || lib_pin_name==q} -quiet]
  }
  if {[sizeof_collection $pins_to_check] == 1} {
    return $pins_to_check
  }
  return [index_collection [sort_collection -limit 1 $pins_to_check max_slack] 0]
}

# include - add rise/fall for FF and positive/negative for latch
proc sio_cell_type_by_pin {pin {extend_info 0}} {
  if {[get_attribute -quiet $pin object_class] eq "port"} {
    return P
  }
  set is_hier 0
  if {[get_attribute -quiet $pin cell.is_hierarchical] != ""} {
    set is_hier [get_attribute -quiet $pin cell.is_hierarchical]
  }
  set is_bbox 0
  if {[get_attribute -quiet $pin cell.is_black_box] != ""} {
    set is_bbox [get_attribute -quiet $pin cell.is_black_box]
  }
  if {$is_bbox || $is_hier} {
    if {[get_attribute -quiet $pin cell.is_negative_level_sensitive] || [get_attribute -quiet $pin cell.is_positive_level_sensitive]} {
      return BL
    }
    return B
  }
  if {[get_attribute -quiet $pin cell.is_negative_level_sensitive] || [get_attribute -quiet $pin cell.is_positive_level_sensitive]} {
    if {$extend_info} {
      if {[get_attribute -quiet $pin cell.is_negative_level_sensitive]} {
        return "Latch Neg"
      } elseif {[get_attribute -quiet $pin cell.is_positive_level_sensitive]} {
        return "Latch Pos"
      }
      return L
    }
    return L
  }
  if {[get_attribute $pin cell.is_sequential -quiet]} {
    if {$extend_info} {
      if {[get_attribute $pin cell.is_fall_edge_triggered -quiet]} {
        return "FF Fall"
      } elseif {[get_attribute $pin cell.is_rise_edge_triggered -quiet]} {
        return "FF Rise"
      }
      return FF
    }
    return F
  }
  return NA
}

proc sio_mow_tp_points_of_interess_many_paths {tps} {
  set ret_points [list]
  set ret_point_of_interess [list]
  array set ret_point_of_interess_done [list]
  set pars [get_partitions]

  foreach_in_collection tp $tps {
    set xys [server_mow_server_get_xys $tp]
    lassign [lindex $xys 0] x y
    set ret [list]
    set slack [get_attribute $tp slack -quiet]
    if {$slack eq "" || $slack eq "INFINITY"} {
      set slack \"NA\"
    }

    set last_par [get_partitions_from_name [get_attribute $tp startpoint.full_name] $pars]
    set i 0
    foreach_in_collection point [get_attribute $tp points] {
      incr i
      set name [get_attribute $point object.full_name]
      set par [get_partitions_from_name $name $pars]
      catch {
        if {[string match *innovus [info nameofexecutable]]} {
          set x [expr double([get_attribute $point x_coordinate -quiet])]
          set y [expr double([get_attribute $point y_coordinate -quiet])]
        } else {
          set x [expr double([get_attribute $point x_coordinate -quiet])/1000]
          set y [expr double([get_attribute $point y_coordinate -quiet])/1000]
        }
      }

      set direction port
      if {!($i == 1 || $i == [sizeof_collection [get_attribute $tp points]])} {
        if {$par eq "/" || $par eq $last_par} {
          continue
        }
      }
      if {$i == 1} {
        set direction startpoint
      }
      if {$i == [sizeof_collection [get_attribute $tp points]]} {
        set direction endpoint
      }

      lappend ret $x $y
      if {![info exists ret_point_of_interess_done($name)]} {
        set ret_point_of_interess_done($name) 1
        if {$ret_point_of_interess ne ""} {
          append ret_point_of_interess ,
        }
        append ret_point_of_interess \{"x":$x,"y":$y,"name":"$name","direction":"$direction","slack":$slack\}
      }
      set last_par $par

    }
    lappend ret_points $ret
  }
  return [list $ret_points \[$ret_point_of_interess\]]
}


proc sio_mow_tp_points_of_interess {tps} {
  set ret ""
  array set done [list]
  foreach_in_collection tp $tps {
    set starttype [sio_cell_type_by_pin [get_attribute $tp startpoint] 1]
    set endtype [sio_cell_type_by_pin [get_attribute $tp endpoint] 1]
    set coords [server_mow_server_get_xys $tp]
    if {[llength $coords] > 3} {
      set number_of_leaf_loads [get_attribute $tp startpoint.net.number_of_leaf_loads -quiet]
      if {$number_of_leaf_loads eq ""} {
        set number_of_leaf_loads \"NA\"
      }
      set t \{"x":[lindex $coords 0],"y":[lindex $coords 1],"direction":"startpoint","type":"$starttype","name":"[get_attribute $tp startpoint.full_name -quiet]","number_of_leaf_loads":$number_of_leaf_loads,"cell":"[get_attribute $tp startpoint.cell.ref_name -quiet]"\}
      if {![info exists done($t)]} {
        if {$ret ne ""} {
          append ret ,
        }
        append ret $t
      }
      set number_of_leaf_loads [get_attribute $tp endpoint.net.number_of_leaf_loads -quiet]
      if {$number_of_leaf_loads eq ""} {
        set number_of_leaf_loads \"NA\"
      }
      set t ,\{"x":[lindex $coords end-1],"y":[lindex $coords end],"direction":"endpoint","type":"$endtype","name":"[get_attribute $tp endpoint.full_name -quiet]","number_of_leaf_loads":$number_of_leaf_loads,"cell":"[get_attribute $tp endpoint.cell.ref_name -quiet]"\}
      if {![info exists done($t)]} {
        append ret $t
      }
    }
    foreach_in_collection c [filter_collection [get_attribute $tp points.object] {!is_port&&!is_hierarchical&&direction==out&&defined(x_coordinate)}] {
      if {[get_attribute $c full_name -quiet] ne [get_attribute $tp startpoint.full_name -quiet] && [get_attribute $c full_name -quiet] ne [get_attribute $tp endpoint.full_name -quiet]} {
        if {[string match *innovus [info nameofexecutable] ]} {
          set x [get_attribute $c x_coordinate -quiet]
          set y [get_attribute $c y_coordinate -quiet]
        } else {
          set x [expr double([get_attribute $c x_coordinate -quiet])/1000]
          set y [expr double([get_attribute $c y_coordinate -quiet])/1000]
        }
        set number_of_leaf_loads [get_attribute $c net.number_of_leaf_loads -quiet]
        if {$number_of_leaf_loads eq ""} {
          set number_of_leaf_loads \"NA\"
        }
        set type [sio_cell_type_by_pin $c 1]
        set ref_name [get_attribute $c cell.ref_name -quiet]
        if {$type eq "NA"} {
          set type [expr {[check_regexs_buffs_invs $ref_name]?"BUFF/INV":"NA"}]
        }
        set t ,\{"x":$x,"y":$y,"type":"$type","direction":"out","name":"[get_attribute $c full_name -quiet]","number_of_leaf_loads":$number_of_leaf_loads,"cell":"$ref_name"\}
        if {![info exists done($t)]} {
          append ret $t
        }
      }
    }
  }
  return "\[${ret}\]"
}

proc sio_all_start_end_pair_through_port_report {output_file {pins {}} {pba_mode none}} {
  printt "Start: [arginfo]"
  set blocks [get_partitions]
  array set tps [list]
  if {$pins eq ""} {
    set pins [get_pins -of_objects $blocks -filter {direction=~in*}]
  }
  # set pins [index_collection $pins 0 10]
  set total [sizeof_collection $pins]

  foreach_in_collection pin $pins {
    sio_bi_progress_bar [incr i] $total
    set tps([get_attribute $pin full_name]) [get_timing_paths -through $pin -start_end_pair -pba_mode $pba_mode -include_hierarchical_pins]
  }

  lassign [sio_logic_count_path [index_collection $tps([get_attribute [index_collection $pins 0] full_name]) 0] 1] header
  set out [open $output_file w]
  puts $out "port,${header}"
  foreach {port tps_data} [array get tps] {
    foreach line [sio_logic_count_path $tps_data] {
      puts $out "${port},$line"
    }
  }
  close $out
  printt "Done: [arginfo]"
}
proc sio_all_fanin_fanout_through_port_report {output_file {pins {}}} {
  printt "Start: [arginfo]"
  set blocks [get_partitions]
  array set tps [list]
  if {$pins eq ""} {
    set pins [get_pins -of_objects $blocks -filter {direction=~in*}]
  }
  # set pins [index_collection $pins 0 10]
  set total [sizeof_collection $pins]

  foreach_in_collection pin $pins {
    sio_bi_progress_bar [incr i] $total
    set tps([get_attribute $pin full_name]) [sio_all_fanin_fanout_through_port -through $pin]
  }

  lassign [sio_logic_count_path [index_collection $tps([get_attribute [index_collection $pins 0] full_name]) 0] 1] header
  set out [open $output_file w]
  puts $out "port,${header}"
  foreach {port tps_data} [array get tps] {
    foreach line [sio_logic_count_path $tps_data] {
      puts $out "${port},$line"
    }
  }
  close $out
  printt "Done: [arginfo]"
}
proc sio_all_fanin_fanout_through_port {args} {
  parse_proc_arguments -args $args results
  # printt "Start: [arginfo]"
  set verbose 0
  set TIME_start 0
  if {[info exists results(-verbose)]} {
    set verbose [set results(-verbose)]
  }
  set pba_mode none
  if {[info exists results(-pba_mode)]} {
    set pba_mode $results(-pba_mode)
  }
  set fanin_fanout_all $results(-fanin_fanout_all)
  if {!$verbose} {suppress_message UITE-629}
  set port $results(-through)
  set pins [get_pins $port]
  set tps [list]
  set dev_null [open /dev/null w]
  array set done {}
  set allfanin [list]
  set allfanout [list]
  set delay_type [sio_mow_get_delay_type]
  foreach_in_collection pin $pins {
    set pin_name [get_attribute $pin full_name]
    if {$fanin_fanout_all ne "fanin_only"} {
      set allfanout [all_fanout -from $pin -endpoints_only -flat]
      # printt [sizeof_collection $allfanout]
    }
    if {$fanin_fanout_all ne "fanout_only"} {
      set allfanin [all_fanin -to $pin -startpoints_only -flat]
      # printt [sizeof_collection $allfanin]
    }

    if {$verbose} {
      printt "Start: [get_attribute $pin full_name] allfanin:[sizeof_collection $allfanin] allfanout:[sizeof_collection $allfanout] tps:[sizeof_collection $tps]"
      set TIME_start [clock clicks -milliseconds]
    }
    # startpoint_unconstrained_reason endpoint_unconstrained_reason
    foreach_in_collection startpoint $allfanin {
      redirect -channel $dev_null {
        set tp [get_timing_paths -from $startpoint -through $pin -pba_mode $pba_mode -include_hierarchical_pins -delay_type $delay_type]
      }
      set key "[get_attribute $tp startpoint.full_name],[get_attribute $tp endpoint.full_name]"
      if {[sizeof_collection $tp] > 0 && ![info exists done($key)]} {
        append_to_collection tps -unique $tp
        # set done($key) 1
      }
    }
    foreach_in_collection endpoint $allfanout {
      redirect -channel $dev_null {
        set tp [get_timing_paths -to $endpoint -through $pin -pba_mode $pba_mode -include_hierarchical_pins -delay_type $delay_type]
      }
      set key "[get_attribute $tp startpoint.full_name],[get_attribute $tp endpoint.full_name]"
      if {[sizeof_collection $tp] > 0 && ![info exists done($key)]} {
        append_to_collection tps -unique $tp
        # set done($key) 1
      } else {
        if {$verbose} {
          printt "Skipping duplicate path $key"
        }
      }

    }

    if {$verbose} {
      printt "Done: $pin_name allfanin:[sizeof_collection $allfanin] allfanout:[sizeof_collection $allfanout] tps:[sizeof_collection $tps]"
      printt "Runtime: [set secs [expr ([clock clicks -milliseconds] - $TIME_start)*0.001]] [expr double([sizeof_collection $allfanin]+[sizeof_collection $allfanout])/$secs]"
    }
  }
  close $dev_null
  if {!$verbose} {unsuppress_message UITE-629}
  # printt "Done: [arginfo] [sizeof_collection $tps]"
  return [sort_collection $tps slack]
}
define_proc_attributes sio_all_fanin_fanout_through_port -info "Return paths with all permutations of fanins and fanouts of given port" -define_args [list \
  {"-through" "port" port string required} {"-pba_mode" "pba_mode" pba_mode string optional} \
  {"-fanin_fanout_all" "type of timing pointes: fanin_only, fanout_only, all" "" one_of_string {optional {default all} {values {all fanin_only fanout_only}}}} \
  {"-verbose" "Verbose output" "" boolean optional}]

proc sio_bi_progress_bar {cur tot {color blue}} {
  # draw progress bar
  set col [lsearch [list black red green yellow blue magenta cyan white] ${color}] ;# replace color with index (int)
  if { $col==-1 } { set col 4	} ;# if the given color does not exists

  set total 60; # set to total width of progress bar
  set half 30;

  set percent [expr {100.*$cur/$tot}]
  set val (\ [format "%4.2f%%" $percent]\ ) ; # print the value at the middle

  set done [expr round($percent * $total/100)]
  set left [expr $total - $done ]
  set str "\033\[01;4${col}m\[[string repeat = ${done}]>\033\[0m[string repeat " " ${left}]\] $val "
  puts -nonewline stderr "$str\r"
}

proc sio_mow_load_loop_status {output_file} {
  printt "Start: [arginfo]"
  set debug 0
  suppress_message UITE-629

  set period [get_attribute [index_collection [get_clock mclk_meu] 0] period]
  set out [open $output_file w]
  # set header "agu_pin,cway_pin,agu_cway_slack,cway_agu_slack,agu_cway_normalized_slack,cway_agu_normalized_slack,total_slack"
  set header "agu_pin,cway_pin,agu_cway_slack,agu_cway_no_adj,cway_agu_slack,cway_agu_no_adj,total_slack,four_cycles_no_adj"
  puts $out $header
  flush $out
  set is_icore [expr {[get_cells icore0 -quiet] eq ""}]
  set par par_meu
  if {!$is_icore} {
    set par icore0/par_meu
  }
  set pin_agu_start [ get_pins -hier -filter full_name=~${par}/*agu*Ags*dataM304H_reg*/o*&&direction==out]
  if {$debug} {
    echo "!!!!!!!!!!DEBUG!!!!!!!!!!!!!"
    set pin_agu_start [index_collection $pin_agu_start 100 210]

    set pin_agu_start [get_pins icore0/par_meu/agu/agus/agend_ld/Ags2dataM304H_reg_23__6_/o]
  }
  set pin_lintag [get_pins -hier -filter full_name=~${par}/*dcu/dcu_l0/*way_part*dcl0lintagrfip*]
  set pin_CWay [get_pins -hier -filter full_name=~${par}/*CWaySelLdM403H*reg*/d]
  set i 0
  set total [sizeof_collection $pin_agu_start]
  foreach_in_collection pin $pin_agu_start {
    if {[info procs bi_progress_bar] != ""} {bi_progress_bar [incr i] $total red}
    set tp_agu_CWays [get_timing_paths -through $pin -through $pin_lintag -to $pin_CWay -max_paths 100 -start_end_pair -normalized_slack]
    foreach_in_collection tp_agu_CWay $tp_agu_CWays {
      set line [list]
      set cell_CWay [get_attribute $tp_agu_CWay endpoint.cell]
      if {[sizeof_collection $tp_agu_CWay] == 0} {
        if {$debug} {
          echo problem [get_attribute $pin full_name]
        }
        continue
      }
      array set prev_next [get_to_and_from_from_tp $tp_agu_CWay]
      array set aa [set prev_next(prev)]
      set t "get_timing_paths -from [get_attribute $cell_CWay full_name] $aa(args) -normalized_slack"
      set tp_CWay_agu [eval $t]
      if {[sizeof_collection $tp_CWay_agu] == 0} {
        if {$debug} {
          echo problem 2 [get_attribute $tp_agu_CWay startpoint.full_name] $t
        }
        continue
      }
      set slack NA
      catch {set slack [expr [get_attribute $tp_agu_CWay slack] + [get_attribute $tp_CWay_agu slack]]}
      set agu_CWay_no_adj NA
      catch {set agu_CWay_no_adj [expr 2*$period*[get_attribute $tp_agu_CWay normalized_slack_no_close_edge_adjustment]]}
      set CWay_agu_no_adj NA
      catch {set CWay_agu_no_adj [expr 2*$period*[get_attribute $tp_CWay_agu normalized_slack_no_close_edge_adjustment]]}
      set four_cycles_no_adj NA
      catch {set four_cycles_no_adj [expr $agu_CWay_no_adj + $CWay_agu_no_adj]}

      lappend line [get_attribute $tp_agu_CWay startpoint.full_name]
      lappend line [get_attribute $tp_agu_CWay endpoint.full_name]

      lappend line [get_attribute $tp_agu_CWay slack]
      lappend line $agu_CWay_no_adj
      lappend line [get_attribute $tp_CWay_agu slack]
      lappend line $CWay_agu_no_adj
      lappend line $slack
      lappend line $four_cycles_no_adj

      if {$debug} {
        echo $line
      }
      puts $out [join $line ,]
      flush $out
      unset prev_next
      unset aa
    }
  }
  close $out
  unsuppress_message UITE-629
  printt "Done: [arginfo]"
}

proc printt_debug {msg lvl} {
  if {$lvl == 0} {
    return
  }
  if {$lvl == 1} {
    printt "-DEBUG- $msg"
  }
}
proc sio_mow_get_rc_cell_delay_per_par {points} {
  set data [list]
  set debug 0
  array set delay_by_type [list rc_delay 0.0 inv/buff_dealy 0.0 logic_cell_delay 0.0 ebb_delay 0.0]
  set prev_point_cell "prev_point_cell"
  set point [index_collection $points 0]
  set pre_arrival [get_attribute $point arrival]
  set pre_point_name [get_attribute $point object.cell.full_name -quiet]
  set partitions [get_partitions]
  set last_port [get_attribute $point object.full_name]
  set last_point_partition [get_partition_from_name [get_attribute $point object.full_name] $partitions]
  set i 0
  set skip_till ""
  set point_full_name ""
  set point_partition NA
  foreach_in_collection point $points {
    incr i
    set point_full_name [get_attribute $point object.full_name -quiet]
    if {$skip_till ne ""} {
      if {$skip_till ne $point_full_name} {
        continue
      } else {
        set skip_till ""
      }
    }
    set is_hier 0
    set is_bbox 0
    set partition_changed 0
    set arrival [get_attribute $point arrival]
    set cur_delay [expr $arrival - $pre_arrival]
    set point_name [get_attribute $point object.cell.full_name -quiet]
    set point_cell_name [get_attribute $point object.cell.ref_name -quiet]
    set point_partition [get_partition_from_name $point_full_name $partitions]
    if {[get_attribute -quiet $point object.cell.is_hierarchical] != ""} {
      set is_hier [get_attribute -quiet $point object.cell.is_hierarchical]
    }
    if {[get_attribute -quiet $point object.cell.is_black_box] != ""} {
      set is_bbox [get_attribute -quiet $point object.cell.is_black_box]
    }
    if {$last_point_partition ne $point_partition} {
      lassign [sio_mow_check_spec_get_realted_arrival_to_port $points $i] related_perc arrival_related pin_drv pin_rcv
      set skip_till $pin_rcv
      printt_debug "$point_full_name" $debug
      set last_point_partition [get_partition_from_name $pin_drv $partitions]
      set point_partition [get_partition_from_name $pin_rcv $partitions]
      set cur_delay [expr $cur_delay + $arrival_related]
      set arrival [expr $arrival + $arrival_related]
      set partition_changed 1
    }
    if {$is_hier} {
      set delay_by_type(rc_delay) [expr $delay_by_type(rc_delay) + $cur_delay]
    } elseif {$point_name ne $pre_point_name} {
      set delay_by_type(rc_delay) [expr $delay_by_type(rc_delay) + $cur_delay]
    } elseif {[check_regexs_buffs_invs $point_cell_name]} {
      set delay_by_type(inv/buff_dealy) [expr $delay_by_type(inv/buff_dealy) + $cur_delay]
    } elseif {$is_bbox} {
      set delay_by_type(ebb_delay) [expr $delay_by_type(ebb_delay) + $cur_delay]
    } else {
      set delay_by_type(logic_cell_delay) [expr $delay_by_type(logic_cell_delay) + $cur_delay]
    }
    if {$partition_changed} {
      set j $i
      set port NA
      while {[incr j -1]} {
        set port [get_attribute [index_collection $points $j] object.full_name]
        if {[get_partition_from_name $port $partitions] eq $last_point_partition} {
          break
        }
      }
      lappend data "$last_point_partition $last_port $port [array get delay_by_type]"
      foreach b [array names delay_by_type] {
        set delay_by_type($b) 0.0
      }
      set last_port $point_full_name
    }
    set pre_point_name $point_name
    set pre_arrival $arrival
    set last_point_partition $point_partition
  }
  lappend data "$point_partition $last_port $point_full_name [get_attribute $point full_name] [array get delay_by_type]"
  return $data
}
proc sio_all_fanin_fanout_ff_to_ff {output_file {blocks {}}} {
  printt "Start: [arginfo]"
  set debug 0
  if {[llength $blocks] == 0} {
    set blocks [get_partitions]
  }
  set pins [get_pins -of_objects $blocks -filter {direction=~out}]
  if {$debug} {
    set pins [index_collection $pins 0 10]
    # set pins [get_pins par_ooo_vec/rsvecsbidm301h_10__6_0_[6]]
  }
  set lines [list]
  set header_delay_names ""
  echo "[sizeof_collection $pins]"
  set i_progress 0
  foreach_in_collection pin $pins {
    sio_bi_progress_bar [incr i_progress] [sizeof_collection $pins]
    set pin_name [get_attribute $pin full_name]
    set pin_partition [get_partition_from_name $pin_name]
    set tps [sio_all_fanin_fanout_through_port -through $pin_name -fanin_fanout_all fanin]
    foreach_in_collection tp $tps {
      if {[sizeof_collection [get_attribute $tp points]] < 2 || [get_attribute $tp slack] eq "INFINITY"} {
        continue
      }
      set data [sio_mow_get_rc_cell_delay_per_par [get_attribute $tp points]]

      array set delay_data [lassign [lindex $data 0] partition startpoint_name port]
      set delay_data_l [list]
      set delay 0.0
      if {$header_delay_names eq ""} {
        set header_delay_names [lsort [array names delay_data]]
      }
      foreach n $header_delay_names {
        lappend delay_data_l $delay_data($n)
        set delay [expr $delay + $delay_data($n)]
      }

      if {$port ne $pin_name} {
        continue
      }
      set endpoint_name [get_attribute ${tp} endpoint.full_name]
      set slack [get_attribute -quiet ${tp} slack]
      set normalized_slack [ get_attribute -quiet ${tp} normalized_slack]
      set startpoint_clk [get_attribute -quiet ${tp} startpoint_clock_latency]
      set endpoint_clk [get_attribute -quiet ${tp} endpoint_clock_latency]
      set startpoint_clk_name [get_attribute -quiet ${tp} startpoint_clock.full_name]
      set endpoint_clk_name [ get_attribute -quiet ${tp} endpoint_clock.full_name]
      set startpoint_type [sio_cell_type_by_pin [get_attribute ${tp} startpoint] 1]
      set endpoint_type [sio_cell_type_by_pin [get_attribute ${tp} endpoint] 1]
      set startpoint_real_name [get_startpoint_real_name [get_attribute ${tp} points]]
      lassign [get_real_prev_slack $tp] slack_prev slack_norm_prev
      lappend lines "${pin_name},${startpoint_name},${startpoint_real_name},${endpoint_name},${slack},${normalized_slack},\
        ${startpoint_clk},${endpoint_clk},${startpoint_clk_name},${endpoint_clk_name},\
        ${delay},[join $delay_data_l ,],${startpoint_type},${endpoint_type},${slack_prev},${slack_norm_prev}"
    }
  }
  set out [open $output_file w]
  puts $out "port,startpoint,startpoint_real_name,endpoint,slack,normalized_slack,startpoint_clk_latency,endpoint_clk_latency,\
    startpoint_clk_name,endpoint_clk_name,delay,[join $header_delay_names ,],startpoint_type,endpoint_type,\
    prev_slack,prev_normalized_slack"
  puts $out [join $lines \n]
  close $out
  printt "Done: [arginfo]"
}
proc get_startpoint_real_name {points} {
  set fn [get_attribute -quiet [index_collection $points 0] object.full_name]
  if {[get_attribute [index_collection $points 0] object.is_clock_pin]} {
    set fn [get_attribute -quiet [index_collection $points 1] object.full_name]
  }
  return $fn
}
proc get_real_prev_slack {tp} {
  array set prev_next [get_to_and_from_from_tp $tp]
  array set aa [set prev_next(prev)]
  if {[info exists aa(args)] && $aa(args) ne ""} {
    set t "get_timing_paths $aa(args)"
    set tp_prev [eval $t]
    return [list [get_attribute $tp_prev slack] [get_attribute $tp_prev normalized_slack]]
  }
  return NA NA
}

proc sio_mow_ebb_clock_mean {output_file} {
  printt "Start: [arginfo]"
  suppress_message UITE-629
  #removes GLBDRV
  set ebbs [get_lib_cells -of_objects [get_libs] -filter {is_black_box&&number_of_pins>1&&!is_combinational&&base_name!~'i0mgdv*'}]
  set insts [get_cells -of_objects $ebbs]
  # set insts [index_collection $insts 0 1]
  set data [list]
  set keys [list rise_to from fall_to from]
  foreach_in_collection ebb $insts {
    set clock_pins [get_pins -of_objects $ebb -filter is_clock_pin]
    foreach_in_collection clock_pin $clock_pins {
      set tp {}
      foreach {to from} $keys {
        foreach delay_type {min max} {
          set key ${to},${from},${delay_type}
          set data_to_from($key) [list 0.0 0.0 0.0 0.0]
          set tps [get_timing_paths -${to} ${clock_pin} -${from} mclk_* -delay_type ${delay_type}]
          set i 0
          foreach tp $tps {
            lassign [sio_mow_ebb_clock_mean_tp $tp] mean mean_rc mean_cell sensit
            set data_to_from($key) [list $mean $sensit]
          }
        }
      }
      set line [list]
      lappend line [get_attribute $ebb ref_name]
      lappend line [get_attribute $ebb full_name]
      lappend line [get_attribute $clock_pin full_name]
      foreach {to from} $keys {
        foreach delay_type {min max} {
          set key ${to},${from},${delay_type}
          lappend line {*}$data_to_from($key)
        }
      }
      lappend data [join $line ,]
    }
  }

  set out [open $output_file w]
  set header [list ebb instance clock_pin]
  foreach {to from} $keys {
    foreach delay_type {min max} {
      foreach m {mean sensit} {
        set key $delay_type:${to}
        lappend header "${m} $key"
      }
    }
  }
  puts $out [join $header ,]
  puts $out [join $data "\n"]
  close $out
  printt "Done: [arginfo]"
  unsuppress_message UITE-629
}

#returns mean, rc mean and cell mean
proc sio_mow_ebb_clock_mean_tp {tp} {
  set sensit [expr abs([get_attribute $tp arrival]-[get_attribute $tp variation_arrival.mean])/$::timing_pocvm_report_sigma]
  set points [get_attribute $tp points]
  set means [get_attribute $points variation_arrival.mean]
  set mean [expr [lindex $means end] - [lindex $means 0]]
  set mean_rc 0.0
  set mean_cell 0.0
  set prev_arrival [get_attribute [index_collection $points 0] variation_arrival.mean]
  set prev_object [get_attribute [index_collection $points 0] object]
  foreach_in_collection point [index_collection $points 1 end] {
    set object [get_attribute $point object]
    if {[get_attribute -quiet $object cell.is_hierarchical]} {
      continue
    }
    set arrival [get_attribute $point variation_arrival.mean]
    set pin_direction [get_attribute $object pin_direction]
    if {$pin_direction eq "in" && [get_attribute $object cell.full_name] ne [get_attribute $prev_object cell.full_name]} {
      set mean_rc [expr $mean_rc + $arrival - $prev_arrival]
    } else {
      set mean_cell [expr $mean_cell + $arrival - $prev_arrival]
    }
    set prev_arrival $arrival
    set prev_object $object
  }
  return [list $mean $mean_rc $mean_cell $sensit]
}

proc sio_mow_get_time_unit {} {
  # source /usr/intel/pkgs/tcl-tk/8.6.13/lib/tcllib1.21/units/units.tcl
  set default_units ps
  redirect -variable a {report_units -nosplit}
  foreach line [split $a \n] {
    set other [lassign [split $line :] cu]
    set cu [string trim $cu]
    set other [string map [list " " "" ] [string tolower [string trim [join $other " "]]]]
    if {"Time_unit" eq $cu} {
      if {$other eq "1e-12second" || $other  eq "1ps"} {
        set default_units ps
      }
      if {$other eq "1e-09second" || $other eq "1ns"} {
        set default_units ns
      }
    }
  }
  return $default_units
}

proc tps_to_sankey {tps} {
  set debug 0
  set node_id 0
  array set node_to_id [list]
  array set id_to_node [list]
  set partitions [get_partitions]
  array set links_uniq [list]
  set label [list]
  foreach_in_collection tp $tps {
    set points [get_attribute $tp points]
    set prev_id -1
    set prev_par ""
    set prev_arrival 0.0
    set i -1
    set goto_point ""
    foreach_in_collection point $points {
      incr i
      set point_name [get_attribute $point object.full_name]
      if {$debug} { echo $point_name }
      if {$goto_point ne ""} {
        if {$goto_point ne $point_name} {
          if {$debug} { echo goto: $goto_point $point_name }
          continue
        }
      }
      set goto_point ""
      set par [get_partition_from_name $point_name $partitions]
      set arrival [get_attribute $point arrival]
      if {![info exists node_to_id($point_name)]} {
        set node_to_id($point_name) $node_id
        set id_to_node($node_id) $point_name
        lappend label $node_id
        incr node_id
      }
      set id $node_to_id($point_name)
      if {$prev_id != -1} {
        set is_port [expr {$par ne $prev_par}]
        if {$is_port} {
          lassign [sio_mow_check_spec_get_realted_arrival_to_port $points $i] related_perc new_arrival pin_drv goto_point
          if {$goto_point eq $point_name} {
            set goto_point ""
          } else {
            if {$debug} { echo start gotot $pin_drv $goto_point $i}
            set arrival [expr $new_arrival + $arrival]
            set id $prev_id
            set prev_id $node_to_id($pin_drv)
          }
        }
        if {[get_attribute -quiet $point object.cell.is_hierarchical] != ""} {
          set is_hier [get_attribute -quiet $point object.cell.is_hierarchical]
        }
        if {$is_hier} {
          if {$debug} { echo cont }
          continue
        }
        set delay [expr $arrival - $prev_arrival]
        if {[expr abs($delay) > 3]} {
          set delay [expr round($delay)]
        } elseif {[expr abs($delay) > 1]} {
          set delay [expr double(round($delay*10))/10]
        }
        set key "$prev_id $id"
        lappend links_uniq($key) $delay
        if {$debug} {puts "$key $delay $id_to_node($prev_id) $id_to_node($id)"}

      }
      set prev_par $par
      set prev_arrival $arrival
      set prev_id $id
    }
  }
  set source [list]
  set target [list]
  set value [list]
  foreach {key v} [array get links_uniq] {
    lassign $key s t
    set v [lsort -real -unique $v]
    foreach vv $v {
      lappend source $s
      lappend target $t
      lappend value {*}$v
    }
  }
  return "label [join $label ,] source [join $source ,] target [join $target ,] value [join $value ,]"
}

proc dump_paths_to_JGF {paths} {
  # https://github.com/jsongraph/json-graph-specification/tree/master
  set graphs [list]
  foreach_in_collection tp $paths {
    # "nodes": { "a": {}, "b": {}, "c": {}, "d": {}, "e": {}, "f": {}, "g": {}, "h": {} },
    array set nodes {}
    set nodes_metadata [list]
    # [{ "source": ["a", "b", "c"], "target": ["f", "g"], "metadata": { "weight": 17 } },]
    set edges {}
    set points [get_attribute $tp points]
    lappend graphs [list '"directed":true' '"metadata":{}']
  }
}

proc dump_paths_to_JGF_points {points} {
  array set nodes {}
  set nodes_metadata [list]
  foreach_in_collection point $points {
    array set nodes [dump_paths_to_JGF_point_node $point]
  }
}

proc dump_paths_to_JGF_point_node {point} {
  set name [get_attribute $point object.full_name]
  set object_class [get_attribute $point object.object_class]
  set direction [get_attribute $point object.direction -quiet]
  set x [get_attribute $point x_coordinate -quiet]
  set y [get_attribute $point y_coordinate -quiet]
  if {$object_class ne "port"} {
    set cell [get_attribute $point object.ref_name]
  }
  if {[catch {[expr $x - $y]}]} {
    set x null
    set y null
  }
}

proc sio_mow_get_interface_between {par1 par2 as_csv} {
  set ret [list]
  set pins [get_pins -of_objects ${par1}]
  set par2 [get_attribute [get_cells ${par2}] full_name]
  array set bus_count {}
  foreach_in_collection pin $pins {
    set net [get_nets -top -of_objects $pin -quiet -segments]
    if {[sizeof_collection $net] == 1} {
      set pin_name [get_attribute $pin full_name]
      set pin2 [get_pins -of_objects $net -filter full_name!=$pin_name&&full_name=~${par2}/* -quiet]
      if {[sizeof_collection $pin2] == 1} {
        lappend ret [list $pin_name [get_attribute $pin2 full_name] [get_attribute $pin2 direction] [get_attribute $pin2 max_slack] \
          [set cp [compress_pin_name $pin_name]] [compress_pin_name [get_attribute $pin2 full_name]]]
        if {![info exists bus_count($cp)]} {
          set bus_count($cp) 1
        } else {
          incr bus_count($cp)
        }
      }
    }
  }
  if {$as_csv} {
    set rr [list]
    puts "pin1_full_name,pin2_full_name,direction,max_slack,pin1_full_name_compress,pin2_full_name_compress,bus_count"
    foreach r $ret {
      lappend rr [join $r ,],$bus_count([lindex $r 4])
    }
    return [join $rr "\n"]
  }
  return $ret
}

proc sio_min_delay_report_logic_count_path {args} {
  set delay_type max
  if {[string match *min* $::ivar(sta,delay_type)]} {
    set delay_type min
  }
  set default_args [list -include_hierarchical_pins -delay_type $delay_type]
  lappend default_args {*}$args
  set tp [get_timing_paths {*}$default_args]
  if {[sizeof_collection $tp] == 0} {return}
  return [join [sio_logic_count_path $tp 1] "\n"]
}

proc sio_mow_parse_locations_ryl {fin} {
  set ret [list]
  set in [open $fin]
  while {[gets $in l] >= 0} {
    set coords [lindex [lassign [split $l ,] type block inst] 0]
    set cc [list]
    foreach c $coords {
      lassign $c x y
      lappend cc ${x},${y}
    }
    lappend ret [list [string trim $type] [string trim $block] [string trim $inst] [join $cc ,]]
  }
  close $in
  return $ret
}

proc sio_mow_gil_find_period {fin} {
  set ret -1
  set in [open_file $fin]
  while {[gets $in l] >= 0} {
    if {[string match "*periodCache\(mclk_pll*" $l]} {
      lassign [split $l ;] toparse
      return [lindex [regexp -all -inline -- {[0-9]+} $l] end]
      break
    }
  }
  close $in
}

proc write_xml_like_from_tps {tps xml} {
  set out [open $xml w]
  puts $out "<xml>"
  set i 0
  foreach_in_collection tp $tps {
    incr i
    set startpoint [get_attribute $tp startpoint.full_name]
    set endpoint [get_attribute $tp endpoint.full_name]
    set l "<path int_ext=\"external\" startpoint=\"$startpoint\" endpoint=\"$endpoint\" path_id=\"$i\" />"
    puts $out $l
  }
  puts $out "</xml>"
  close $out
}

proc to_pins_to_xml {} {
  # TODO: replace hardcoded path
  set fin /nfs/site/home/ayarokh/tmp/to_pins.txt
  set in [open $fin]
  set tps [list]
  while {[gets $in l] >0} {
    set l [string map {"icore0/" "" "icore1/" ""} $l]
    # echo $l
    set tp [get_timing_path -to $l -delay_type min]
    append_to_collection tps $tp
  }
  puts [sizeof_collection $tps]
  write_xml_like_from_tps $tps ./par_fma_min_delay.xml
  write_collection -file ./par_fma_min_delay.csv -columns {endpoint.full_name slack} -format csv $tps
  close $in
}

#write xml for min/max report
proc run_sio_mow_get_start_end_through_pin_tp {outfile} {
  suppress_message {UITE-502}
  set pins [get_pins par_fmav?/*]
  set tps [sio_mow_get_start_end_through_pin_tp $pins]
  write_xml_like_from_tps $tps [pwd]/[set ::clock_scenario].xml
  echo "Done: [pwd]/[set ::clock_scenario].xml"
}


proc sio_mow_set_dont_touch_on_tip {} {
  set tip_cells [get_cells -quiet {icore*/par_*/tip_cell_* par_*/tip_cell_*}]
  array set tip_cell_arr {}
  foreach_in_collection cell $tip_cells {
    set tip_cell_arr([get_attribute $cell full_name]) 1
  }
  set pins [get_pins -of_objects $tip_cells -filter {pin_direction==out}]
  array set failed_pins {}
  set tip_nets {}
  foreach_in_collection pin $pins {
    set inpins [filter_collection [get_attribute [set net [get_nets -of_objects $pin -segments -top_net_of_hierarchical_group]] leaf_loads] lib_pin_name!=dpd1]
    set any_pin_is_tip 0
    foreach c [get_attribute $inpins cell.full_name] {
      if {[info exists tip_cell_arr($c)]} {
        set any_pin_is_tip 1
        break
      }
    }
    if {$any_pin_is_tip} {
      append_to_collection tip_nets $net
    }
  }
  set i 0
  # foreach {k v} [array get failed_pins] {
  #   printt "$k $v"
  #   if {[incr i] == 100} {
  #     break
  #   }
  # }
  return [list $tip_nets $tip_cells]
  # set_dont_touch [get_nets -segments $tip_nets] true
}

proc sio_mow_pteco_make_stat_qor {infile {fields {}}} {

  set in [open $infile]
  set header ""
  set counts_by {StartClock EndClock}
  array set header_arr {}
  array set line_arr {}
  while {[gets $in l] >= 0} {
    set ll [string trim $l]

    if {$header ne "" && ([string equal -length 7 $l "FixType"] || $ll eq "")} {
      break
    }
    if {$header ne ""} {
      set line [lmap x [split $ll |] {string trim $x}]
      if {[llength $line] != 1 && ![string equal -length 3 "---" $ll]} {
        set i 0
        foreach h $line {
          set line_arr($i) $h
          incr i
        }
        set d {}
        foreach c $fields {
          lappend d $line_arr($header_arr($c))
        }
        if {[llength $fields] == 0} {
          puts [join $line ,]
        } else {
          puts [join $d ,]
        }

        array unset line_arr
      }
    }
    if {$header eq "" && [string equal -length 7 $l "FixType"]} {
      set header [lmap x [split $ll |] {string trim $x}]
      if {[llength $fields] == 0} {
        puts [join $header ,]
      } else {
        puts [join  $fields ,]
      }
      set i 0
      foreach h $header {
        set header_arr($h) $i
        incr i
      }
    }
  }
}
proc sio_mow_pteco_make_stat_path_margin {infile} {
  set in [open $infile]
  set header ""
  array set counts {}
  set counts_by {StartClock EndClock}
  array set header_arr {}
  array set line_arr {}

  while {[gets $in l] >= 0} {
    set ll [string trim $l]
    if {$header ne "" && ([string equal -length 7 $ll "Path id"] || $ll eq "")} {
      break
    }
    if {$header ne ""} {
      set line [lmap x [split $ll |] {string trim $x}]
      if {[llength $line] != 1} {
        set i 0
        foreach h $line {
          set line_arr($i) $h
          incr i
        }
        set d {}
        foreach c $counts_by {
          lappend d $line_arr($header_arr($c))
        }
        set k [join $d ,]
        if {[info exists counts($k)]} {
          incr counts($k)
        } else {
          set counts($k) 1
        }
        array unset line_arr
      }
    }
    if {$header eq "" && [string equal -length 2 $ll "Id"]} {
      set header [lmap x [split $ll |] {string trim $x}]

      set i 0
      foreach h $header {
        set header_arr($h) $i
        incr i
      }
    }
  }
  close $in
  puts [join $counts_by ,],count
  foreach {k v} [lsort -decreasing -stride 2 -index 1 -integer [array get counts]] {
    puts ${k},${v}
  }
}

proc sio_mow_get_clk_target_get {} {
  global sio_mow_get_clk_target
  set pod_on_pll 0
  if {[info exists sio_mow_get_clk_target]} {
    return $sio_mow_get_clk_target
  }
  if {$::env(PROJECT) eq "gfc_n2_client"} {
    set pod_on_pll 1
  }
  set session [lindex [split [sio_session_name_get] .] 1]
  set target 90
  if {$session eq "max_nom"} {
    set target 140
  }
  if {!$pod_on_pll} {
    return [set sio_mow_get_clk_target $target]
  }
  set pins [get_pins * -hierarchical -nocase -filter full_name=~"*_glbdrv_*/glbdrv_*par_*mnsclk*/clkin"||full_name=~"*_glbdrv_*mclk*/*/clkin"||full_name=~"*/par_*glbdrv_*mnsclk*/clkin"]
  if {[sizeof_collection $pins] < 10} {
    return [set sio_mow_get_clk_target $target]
  }
  # foreach_in_collection pin $pins {
  #   echo "[get_object_name $pin]"
  # }
  set arrivals [list]
  suppress_message UITE-629
  foreach_in_collection pin $pins {
    set max_arrival -1
    foreach delay_type {min max} {
      # printt "[get_object_name $pin] $delay_type"
      set path [get_timing_paths -to $pin -delay_type $delay_type -from mclk_pll]
      if {[sizeof_collection $path] > 0} {
        set arrival [get_attribute $path arrival]
        set max_arrival [expr max($arrival, $max_arrival)]
      }
    }
    if {$max_arrival > 0 && $max_arrival ne "Inf"} {
      lappend arrivals $max_arrival
    }
  }
  unsuppress_message UITE-629

  if {[llength $arrivals] < 10} {
    return [set sio_mow_get_clk_target $target]
  }
  set sio_mow_get_clk_target [expr int([lsum $arrivals]/[llength $arrivals]) + $target]
  return $sio_mow_get_clk_target
}

proc sio_mow_pteco_make_stat {d {block ""}} {
  if {$block eq ""} {
    set block $::env(block)
  }
  set fields {FixType Buffers Sized/Swapped Touch MaxTNS MaxWNS MaxPaths MaxR2RTNS MaxR2RWNS MaxR2RPaths MinTNS MinWNS MinPaths MinR2RTNS MinR2RWNS MinR2RPaths Duration
  }
  sio_mow_pteco_make_stat_qor $d/${block}.latest.loops_qor.rpt $fields
  puts ""
  sio_mow_pteco_make_stat_path_margin $d/${block}.path_margin_hold.eco.rpt
}

proc carpet_pt_find_pin_seq {pattern {print 0} {filter {cell.is_sequential&&direction=~in&&lib_pin_name=~d*}}} {
if {[string length $pattern] < 3} {
  puts "-E- pattern $pattern too small"
  return {}
}
set pins [list]
if {[string first / $pattern] > -1} {
  set pins [get_pins -hierarchical -leaf -nocase -filter ${filter}&&full_name=~$pattern]
} else {
  set pins [get_pins -hierarchical -leaf -nocase -filter $filter $pattern]
}
if {$print} {
  if {[sizeof_collection $pins] > 100} {
    puts "-W- print only first 100 pins"
    puts [join [get_attribute [index_collection $pins 0 99] full_name] \n]
  } else {
    puts [join [get_attribute $pins full_name] \n]
  }
  return
}
return $pins
}

proc sio_mow_pteco_check_remove_pattern {} {
  set patterns {*PTECO* *FE_PHC* *FE_PHN* *_h_inst*}
  # TODO: replace hardcoded path
  set files [glob /nfs/site/disks/pnc_bei_ebb/ayarokh/PTECO/core_client_241010_ww40_REMOVE_BUFFERS/runs/core_client/1278.6/pt_eco/outputs/*.final.innovus.tcl]
  array set data {}
  foreach f $files {
    set fin [open $f]
    set block [string map {_core_client.final.innovus.tcl ""} [lindex [split $f /] end]]
    set i 0
    while {[gets $fin l] >= 0} {
      if {[string match eco_delete_repeater* $l]} {
        incr i
        set pin [lindex $l end]
        if {$block eq "core_client.final.innovus.tcl"} {
          set block [lindex [split $pin /] 0]
        }
        set key ${block},all
        if {![info exists data($key)]} {
          set data($key) 1
          foreach p $patterns {
            set key ${block},$p
            set data($key) 0
          }
        } else {
          incr data($key) 1
        }
        foreach p $patterns {
          set key ${block},$p
          if {[string match $p $pin]} {
            incr data($key)
          }
        }
      }
    }
    close $fin
    echo $i $f
  }
  # parray data
  echo block,all,[join $patterns ,]
  foreach {b d} [array get data *,all] {
    set block [lindex [split $b ,] 0]
    # echo $block
    set line ${block},$d
    foreach p $patterns {
      foreach {b d} [array get data ${block},$p] {
        append line , $d
      }
    }
    echo $line
  }
}

proc sio_mow_get_all_lathces {} {
  set seqs [get_cells -hierarchical -filter {is_sequential&&!is_hierarchical&&(is_negative_level_sensitive||is_positive_level_sensitive)&&full_name!~*rfip* && !is_black_box && full_name!~*BIST* && full_name!~*safd* && full_name!~*misr*&&full_name!~*array* && full_name!~*ultiscan* && full_name!~*async*}]
  return $seqs
}
proc sio_check_fdr_ctech_filter_scan_pm {data {dont_use_filter 0}} {
  if {$dont_use_filter} {return $data}
  set pin [get_pins -of_objects $data -filter lib_pin_name==clk]
  if {[sizeof_collection [filter_collection $pin {full_name=~par_pm/*&&(clocks.full_name==scanclk_notdiv_phyex||clocks.full_name==scanclk_div_phyex)}]]} {
    return $data
  }
}
proc sio_check_fdr_ctech_check {fdr} {
  set debug 0
  set fanins [sio_check_fdr_ctech_filter_scan_pm [all_fanin -to $fdr -only_cells -startpoints_only -flat] $debug]
  set fanouts [sio_check_fdr_ctech_filter_scan_pm [all_fanout -from $fdr -only_cells -endpoints_only -flat] $debug]
  if {$debug} {
    printt "fanins [sizeof_collection $fanins] [get_attribute $fdr full_name]"
    printt "fanouts [sizeof_collection $fanouts]"
  }
  array set cmp {}
  array set per_glbdrv_fanin {}
  array set per_glbdrv_fanout {}
  set errors [list]
  foreach_in_collection fanin $fanins {
    set glbdrvin [sio_check_scans_seqs_get_glbdrv $fanin]
    set cmp($glbdrvin) 0
    if {$glbdrvin eq ""} {
      lappend errors "empty_glbdrv_drv,[get_attribute $fdr full_name],,[get_attribute $fanin full_name],"
    } else {
      lappend per_glbdrv_fanin($glbdrvin) [get_attribute $fanin full_name]
    }
  }
  foreach_in_collection fanout $fanouts {
    set glbdrvout [sio_check_scans_seqs_get_glbdrv $fanout]
    if {$glbdrvout eq ""} {
      lappend errors "empty_glbdrv_rcv,[get_attribute $fdr full_name],,,[get_attribute $fanout full_name]"
    }
    if {[info exists cmp($glbdrvout)]} {
      incr cmp($glbdrvout)
      lappend per_glbdrv_fanout($glbdrvout) $glbdrvout
      foreach a [lsort -uniq $per_glbdrv_fanin($glbdrvout)] {
        lappend errors "same_glbdrv,[get_attribute $fdr full_name],$glbdrvout,$a,[get_attribute $fanout full_name]"
      }
    }
  }
  return [list [array get cmp] $errors]
}

proc sio_check_fdr_ctech {file_out file_err_out} {
  global fdr_ctech
  set out [open $file_out w]
  set err_out [open $file_err_out w]
  puts $err_out "fdr_id,error,fdr_name,glbdrve,rcv,drv"
  printt "Start [sizeof_collection $fdr_ctech]"
  set err_count 0
  foreach_in_collection fdr $fdr_ctech {
    set fdr_name [get_attribute $fdr full_name]
    lassign [sio_check_fdr_ctech_check $fdr] cmp errors
    if {[llength $errors]} {
      foreach e $errors {
        puts $err_out "$err_count,$e"
      }
      incr err_count
    }
    foreach {c i} $cmp {
      if {$i} {
        puts $out "$fdr_name,$c,$i"
      }
    }
  }
  printt "Done [sizeof_collection $fdr_ctech]"
  close $out
  close $err_out
}
proc sio_check_scans_seqs {file_out} {
  set filter (clocks.full_name==scanclk_notdiv_phyex||clocks.full_name==scanclk_div_phyex)
  set clocks [get_clocks -filter [string map {clocks. ""} $filter]]
  set out [open $file_out w]
  puts $out "from,to,clocks_from,clocks_to,from_glbdrv,to_glbdrv,check"
  set glbdrv_pins_out [get_pins -hierarchical -filter "cell.ref_name=~*i0mgdv*&&full_name=~par_pm/*&&direction==out"]
  array set cells_to_glbdrv {}
  foreach_in_collection gd $glbdrv_pins_out {
    set seqs [filter_collection [all_fanout -only_cells -endpoints_only -flat -from $gd] is_sequential]
    foreach s [get_attribute $seqs full_name] {
      if {![info exists cells_to_glbdrv($s)]} {
        set cells_to_glbdrv($s) [list]
      }
      lappend cells_to_glbdrv($s) [get_attribute $gd full_name]
      set cells_to_glbdrv($s) [lsort -uniq $cells_to_glbdrv($s)]
    }
  }
  foreach_in_collection gd $glbdrv_pins_out {
    printt "Start: [get_attribute $gd full_name]"
    set seqs [filter_collection [all_fanout -only_cells -endpoints_only -flat -from $gd] is_sequential]
    array set seqs_names {}
    foreach s [get_attribute $seqs full_name] {
      set seqs_names($s) 1
    }
    set count 0
    set pins_drv [get_pins -of_objects $seqs -filter defined(clocks)&&$filter]
    foreach_in_collection pdrv $pins_drv {
      if {[expr [incr count]%1000] ==0} {
        printt "$count/[sizeof_collection $seqs]"
      }
      set fouts [filter_collection [all_fanout -from $pdrv -flat -only_cells -endpoints_only] full_name=~par_pm/*&&is_sequential]
      set pins_rcv [get_pins -of_objects $fouts -filter defined(clocks)&&$filter]
      foreach_in_collection prcv $pins_rcv {
        set rcv_cell [get_attribute $prcv cell.full_name]
        if {![info exists seqs_names($rcv_cell)]} {
          set p1 [get_attribute $pdrv full_name]
          set c1 [get_attribute $pdrv clocks.full_name]
          set c2 [get_attribute $prcv clocks.full_name]
          set g1 [get_attribute $gd cell.full_name]
          set g3 FROM_ARR
          set g2 ""
          if {[info exists cells_to_glbdrv($rcv_cell)]} {
            set g2 $cells_to_glbdrv($rcv_cell)
          } else {
            set g2 [sio_check_scans_seqs_get_glbdrv $rcv_cell]
            set g3 "FROM_PRC"
            if {[expr {$g2 eq $g1}]} {
              continue
            }
          }
          puts $out "$p1,$rcv_cell,$c1,$c2,$g1,$g2,$g3"
        }
      }
    }
    unset seqs_names
  }
  close $out
}
proc sio_check_scans_seqs_get_glbdrv {cell} {
  set pin [get_pins -of_objects $cell -filter lib_pin_name==clk]
  set glb_drv [filter_collection [all_fanin -to $pin -flat -only_cells -startpoints_only] ref_name=~*i0mgdv*]
  return [get_attribute $glb_drv full_name]
}
proc clocks_of_pins {args} {
  foreach_in_collection p [get_pins $args] {
    set pn [get_object_name $p]
    if {[sizeof_collection [get_attribute -quiet $p clocks]] > 0 } {
      set cn [get_object_name [get_attribute -quiet $p clocks]]
      puts "$pn - $cn"
    } else {
      puts "$pn - MISSING_CLOCK"
    }
  }
}

proc sio_mow_dump_logic_count_path {paths {fout stdout}} {
  if {$fout eq "stdout"} {
    set out stdout
  } else {
    set out [open $fout]
  }
  foreach line [sio_logic_count_path $paths 1 1] {
    puts $out [join [lrange [split $line ,] 0 end-2] ,]
  }
  puts $out "\n\n"
  set id 0
  foreach_in_collection path $paths {
    puts "Path id: $id"
    set path_type [get_attribute $path path_type -quiet]
    redirect -variable t {
      report_timing -nosplit -nets -physical -input_pins -capacitance -transition_time -crosstalk_delta -attributes [list object.${path_type}_slack "  "] $path
    }
    puts $out $t
    incr id
  }
  if {$fout ne "stdout"} {
    close $out
  }
}

proc sio_mow_pteco_filter_out_set_attr {f par} {
  suppress_message UIAT-4
  define_user_attribute touched_by_pteco -class cell -type boolean
  set in [open $f]
  while {[gets $in l] >= 0} {
    if {[string match "eco_update_cell*" $l ]} {
      set ll [lindex $l 2]
      echo "set_user_attribute [get_cells icore0/$par/$ll] touched_by_pteco true"
    }
  }
  close $in
}
proc sio_mow_pteco_filter_out_not_mclk {} {
  # TODO: replace hardcoded path
  set fs /nfs/site/disks/pnc_bei_ebb/ayarokh/PTECO/core_client_241105_ww44/runs/core_client/1278.6/pt_eco_run/outputs/splitted_icc2_changelist/par*.final.innovus.tcl

  foreach f [glob $fs] {
    echo $f
    set ii [open $f r]
    set out [open ${f}.mclk w]
    set par [lindex [split [lindex [split $f /] end] .] 0]
    while {[gets $ii l] >= 0} {
      set ll [string trim $l]
      set w 1
      if {[string match eco_add_repeater* $ll] || [string match eco_update_cell* $ll]} {
        set ll [string map {\[ { } \{ { } \} { } \] { } get_pins { } "-pins" { }} $l]
        set a [lindex $ll 2]
        set tp [get_timing_path -through icore0/${par}/$a]
        echo $ll
        echo icore0/${par}/$a

        set is_sp_mclk [string match "mclk_*" [get_attribute $tp startpoint_clock.full_name]]
        set is_ep_mclk [string match "mclk_*" [get_attribute $tp endpoint_clock.full_name]]

        if { !($is_sp_mclk && $is_ep_mclk) } {
          puts $out "# filtered by $::env(USER) not mclk"
          puts $out "# $l"
          set w 0
        }
      }
      if { $w } {
        puts $out $l
      }
    }
    close $out
    close $ii
  }
}
proc sio_mow_pteco_filter_out {} {
  set out [open to_filter_sio_mow_pteco_filter_out.csv]
  set f /nfs/site/disks/baselibr_wa/SIO_WORK/Partition_model/Spec_ci_area/eco_file.tcl
  set in [open $f]
  while {[gets $in l] >= 0} {
    set l [string map {\[ { } \{ { } \} { } \] { } get_pins { }} $l]
    set a [lindex $l 1]
    set to_filter [all_fanin -to $a -flat]
    append_to_collection to_filter [all_fanout -from $a -flat]
    set cells_to_remove [get_cells -of_objects $to_filter -filter touched_by_pteco]
    set pins_to_remove [filter_collection $to_filter full_name=~*pt_eco_buf_*_FCT__PTECO_HOLD_*]
    foreach_in_collection c $cells_to_remove {
      set cn [get_attribute $c full_name]
      set p [get_partition_from_name $cn]
      puts $out "cell,$p,$cn,[string range $cn [string length $p] end]"
    }
    foreach_in_collection c $pins_to_remove {
      set cn [get_attribute $c full_name]
      set p [get_partition_from_name $cn]
      puts $out "pin,$p,$cn,[string range $cn [string length $p] end]"
    }
  }
  close $out
  close $in
}
proc sio_check_scans_seqs_check_endpoints_is_scanclock {pin} {
  return [sizeof_collection [filter_collection $pin {full_name=~par_pm/*&&(clocks.full_name==scanclk_notdiv_phyex||clocks.full_name==scanclk_div_phyex)}]]
}
proc sio_check_scans_seqs_check_endpoints_get_glbdrv {clkpin} {
  set glb_drv [filter_collection [all_fanin -to $clkpin -flat -only_cells -startpoints_only] ref_name=~*i0mgdv*]

}
proc sio_check_scans_seqs_check_endpoints {} {
  set clocks [get_clocks "scanclk_notdiv_phyex scanclk_div_phyex"]

  set endpoints [sio_check_scans_seqs_read_xml vrf_split_all/[set ::scenario]/par_pm/par_pm.int.txt]
  set delay_type [sio_mow_get_delay_type]
  set outfile sio_check_scans_seqs_check_endpoints.[set ::scenario].csv
  echo $outfile
  set out [open $outfile w]
  puts $out "error,startpoint,endpoint,glbdrv start,glbdrv end"
  foreach endpoint $endpoints {
    set tps [get_timing_path -from $clocks -to $clocks -through $endpoint -start_end_pair -delay_type $delay_type]
    if {![sizeof_collection $tps]} {
      puts $out "no TP to,,$endpoint,,"
      continue
    }
    # sio_check_scans_seqs_get_glbdrv
    set endpoint_pin_clock [get_attribute [index_collection $tps 0] endpoint_clock_pin]
    if {![sio_check_scans_seqs_check_endpoints_is_scanclock $endpoint_pin_clock]} {
      puts $out "endpoint_pin_clock is not scanclock,,[get_attribute $endpoint_pin_clock full_name],,"
    }
    set glbdrv_e [sio_check_scans_seqs_check_endpoints_get_glbdrv $endpoint_pin_clock]

    foreach_in_collection startpoint [get_attribute $tps startpoint] {
      if {![sio_check_scans_seqs_check_endpoints_is_scanclock $startpoint]} {
        puts $out "startpoint is not scanclock,[get_attribute $startpoint full_name],,"
      }
      set glbdrv_s [sio_check_scans_seqs_check_endpoints_get_glbdrv $startpoint]
      if {$glbdrv_s eq $glbdrv_e} {
        puts $out "same GLBDRV,[get_attribute $startpoint full_name],$endpoint,$glbdrv_s,$glbdrv_e"
      }

    }
  }
  close $out
}

proc sio_check_scans_seqs_read_xml {xmls} {
  foreach xml [glob $xmls] {
    printt "Start $xml"
    set in [open $xml]
    set d "endpoint="
    array set all_endpoints {}
    while {[gets $in l] >= 0} {
      if {[string match "<path *" $l]} {
        set st_id [expr [string first $d $l]+[string length $d]+1]
        set endpoint [string range $l $st_id [string first \" $l $st_id]-1]
        set all_endpoints($endpoint) 1
      }
    }
    close $in
  }
  return [array names all_endpoints]
}

proc test_server_client {{what 0}} {
  set host sccc05393110
  set port 9904
  set s [socket $host $port]
  fconfigure $s -buffering line
  if {$what} {
    puts $s todo
    gets $s msg
    puts "get todo: $msg"
  } else {
    set msg "data:[::tcl::mathfunc::rand],data"
    puts $s $msg
    puts "sent $msg"
  }

  close $s
}


proc all_startpoints_per_pin {pins output_file} {
  set out [open $output_file w]
  puts $out "pin,startpoint"
  foreach_in_collection pin $pins {
    set fanins [all_fanin -flat -only_cells -startpoints_only -quiet -to $pin]
    set wrote 0
    foreach_in_collection startpoint $fanins {
      set wrote 1
      puts $out "[get_attribute $pin full_name],[get_attribute $startpoint full_name]"
    }
    if {!$wrote} {
      puts $out "[get_attribute $pin full_name],"
    }
  }
  close $out
}

proc sio_get_relax_IO_get_xml_data {xmls} {
  set ret {}
  foreach xml [glob $xmls] {
    printt "Start $xml"
    set in [open $xml]
    set path_fields [list endpoint= startpoint= slack= int_ext= startpoint_clock= endpoint_clock=]
    while {[gets $in l] >= 0} {
      if {[string match "<path *" $l]} {
        array set fields {}
        foreach pf $path_fields {
          set st_id [expr [string first " $pf" $l]+[string length $pf]+2]
          set field [string range $l $st_id [string first \" $l $st_id]-1]
          set fields([string range $pf 0 end-1]) $field
        }
        lappend ret [array get fields]
        unset fields
      }
    }
    close $in
  }
  return $ret
}

proc sio_get_relax_IO_fix_io_constraints {datan io_constraints_old io_constraints_new} {
  upvar $datan data
  set in [open $io_constraints_old]
  set out [open $io_constraints_new w]
  while {[gets $in l] >= 0} {
    set ll [string trim $l]
    set wrote 0
    set key ""
    if {[string match "set_output_delay *" $ll]} {
      set key "output,[lindex $ll end]"
      set clock endpoint_clock
    }
    if {[string match "set_input_delay *" $ll]} {
      set key "input,[lindex $ll end]"
      set clock startpoint_clock
    }
    if {$key ne "" && [info exists data($key)]} {
      array set d $data($key)
      set c [lindex $ll [expr [lsearch -exact $ll {-clock}]+1]]
      if {$d($clock) eq $c} {
        set whereto [lsearch -exact $l {[expr} ]
        set lll [linsert $l [expr ${whereto}+1] +]
        set lll [linsert $lll [expr ${whereto}+1] [expr -1*abs(double($d(slack)))]]
        set wrote 1
        puts $out "# [date] changed by [expr abs(double($d(slack)))]: $l "
        puts $out [join $lll { }]
      }
    }
    if {!$wrote} {
      puts $out $l
    }
  }
  close $out
  close $in
}
proc sio_get_relax_IO {xmls io_constraints_old io_constraints_new} {
  set xml_data [sio_get_relax_IO_get_xml_data $xmls]
  array set data {}
  foreach d $xml_data {
    array set dd $d
    if {$dd(int_ext) eq "ifc_external" && [expr double($dd(slack)) < 0]} {
      if {![string match "*/*" $dd(startpoint)]} {
        set key "input,$dd(startpoint)"
        set data($key) $d
      }
      if {![string match "*/*" $dd(endpoint)]} {
        set key "output,$dd(endpoint)"
        set data($key) $d
      }
    }
    unset dd
  }
  sio_get_relax_IO_fix_io_constraints data $io_constraints_old $io_constraints_new
}

proc sio_mow_get_units_get_coords {} {
  set x_min [get_attribute [index_collection [get_design] 0] x_coordinate_min]
  set x_max [get_attribute [index_collection [get_design] 0] x_coordinate_max]
  set y_min [get_attribute [index_collection [get_design] 0] y_coordinate_min]
  set y_max [get_attribute [index_collection [get_design] 0] y_coordinate_max]
  return [list $x_min $y_min $x_max $y_max]
}

proc sio_mow_get_units_density {outfile} {
  printt "Start: [arginfo]"
  lassign [sio_mow_get_units_get_coords] x_min x_max y_min y_max
  set xstep 1000.0
  set ystep 1000.0
  set partitions [get_partitions]
  set all_cells [get_cells -hierarchical -filter !is_hierarchical&&defined(x_coordinate_max)]
  array set data {}
  array set pls {}
  foreach p $partitions {
    set pls($p) [split $p /]
  }
  set tot 0
  foreach_in_collection cell $all_cells {
    incr tot
    if {[expr $tot % 10000000] == 0} {
      printt "${tot}/[sizeof_collection $all_cells]"
    }
    set full_name [get_attribute $cell full_name]
    set full_name_l [split $full_name /]
    if {[llength $full_name_l] < 3} {
      continue
    }
    set x_min_cell [get_attribute $cell x_coordinate_min]
    set y_min_cell [get_attribute $cell y_coordinate_max]
    if {$x_min_cell eq ""} {
      continue
    }
    set xs [expr int(int($x_min_cell/$xstep)*$xstep)]
    set ys [expr int(int($y_min_cell/$ystep)*$ystep)]
    set unit ""
    foreach {p pl} [array get pls] {
      set plength [llength $pl]
      while {$plength > 0} {
        incr plength -1
        if {[lindex $pl $plength] != [lindex $full_name_l $plength]} {
          set plength -2
          break
        }
      }
      if {$plength != -1} {}
      set unit [join [lrange $full_name_l 0 [llength $pl]] /]
    }
    if {$unit eq ""} {continue}
    set key "$xs,$ys,[expr int($xs+$xstep)],[expr int($ys+$ystep)],$unit"
    if {![info exists data($key)]} {
      set data($key) 1
    } else {
      incr data($key)
    }
  }
  set out [open $outfile w]
  puts $out "xl,yl,xh,yh,unit,count"
  foreach {k v} [array get data] {
    puts $out "${k},$v"
  }
  close $out
  printt "Done"
}
proc sio_maha_tpi_find_check_is_connected_to_ultiscan_prev {pin {exclude {}}} {
  set name _ultiscan_
  set ret {}
  set pins [add_to_collection -unique [get_attribute [get_timing_arcs -to [get_attribute [get_timing_arcs -to $pin -filter !is_cellarc] from_pin] -filter is_cellarc] from_pin] {}]
  foreach_in_collection p $pins {
    set is_ultiscan [sizeof_collection [filter_collection [all_fanin -flat -to $p] full_name=~*${name}*]]
    if {!$is_ultiscan} {
      append_to_collection ret $p
    }
  }
  set to_check [all_fanin -startpoints_only -only_cells -flat -to $ret -quiet]
  set to_check [remove_from_collection $to_check $exclude]
  set pos [filter_collection $to_check (defined(is_positive_level_sensitive)&&is_positive_level_sensitive)||(defined(is_rise_edge_triggered)&&is_rise_edge_triggered)]
  set neg [filter_collection $to_check (defined(is_negative_level_sensitive)&&is_negative_level_sensitive)||(defined(is_fall_edge_triggered)&&is_fall_edge_triggered)]
  set pos2 [remove_from_collection $pos $neg]
  set neg2 [remove_from_collection $neg $pos]
  return [list $pos2 $neg2]
}
proc sio_maha_tpi_find_check_is_connected_to_ultiscan_next {pin {exclude {}}} {
  set to_check [all_fanout -endpoints_only -only_cells -flat -from $pin -quiet]
  set pos2 {}
  set neg2 {}
  if {[sizeof_collection $to_check]} {
    set to_check [remove_from_collection $to_check $exclude]

    set pos [filter_collection $to_check (defined(is_positive_level_sensitive)&&is_positive_level_sensitive)||(defined(is_rise_edge_triggered)&&is_rise_edge_triggered)]
    set neg [filter_collection $to_check (defined(is_negative_level_sensitive)&&is_negative_level_sensitive)||(defined(is_fall_edge_triggered)&&is_fall_edge_triggered)]
    set pos2 [remove_from_collection $pos $neg]
    set pos2 [remove_from_collection $pos2 [get_cells -of_objects $pin]]
    set neg2 [remove_from_collection $neg $pos]
    set neg2 [remove_from_collection $neg2 [get_cells -of_objects $pin]]
  }
  return [list $pos2 $neg2]
}
proc sio_maha_tpi_find {} {
  set slos_cells [paranoia_maha_check_si_connected_to_not_so_get_slos]

  # set ph1_latch [get_cells -hierarchical -filter "is_sequential==true && ref_name=~i0ml* && is_positive_level_sensitive && full_name=~*par_ooo_int*" ]
  # append_to_collection  ph1_latch [get_cells -hierarchical -filter "is_sequential==true && ref_name=~i0mf* && is_rise_edge_triggered && full_name=~*par_ooo_int* " ]
  # set ph2_latch [get_cells -hierarchical -filter "is_sequential==true && ref_name=~i0ml* && is_negative_level_sensitive && full_name=~*par_ooo_int*" ]
  # append_to_collection  ph2_latch [get_cells -hierarchical -filter "is_sequential==true && ref_name=~i0mf* && is_fall_edge_triggered && full_name=~*par_ooo_int*" ]
  # set int_tpi_cells [get_cells -quiet -hierarchical -filter "full_name=~*/DFT_TP_tpi_flop* && full_name=~*par_ooo_int* "]

  ###Synopsis
  append_to_collection -unique tpi_cells [get_cell -quiet -hier -filter "is_sequential&&full_name=~*tp_obs_reg*dtc_reg* "]
  append_to_collection -unique tpi_cells [get_cell -quiet -hier -filter "full_name=~*tp_ctrl_reg*dtc_reg*"]
  ###Cadance
  append_to_collection -unique tpi_cells [get_cells -quiet -hierarchical -filter "is_sequential&&full_name=~*/DFT_TP_tpi_flop* "]
  #added by Maha request: 250311
  append_to_collection tpi_cells [get_cells -quiet -hierarchical -filter "full_name=~*/DFT_TP_CDNS_*_tpi_flop*"]
  set observe_regular {}
  set observe_with_loop {}
  set control_regular {}
  set control_with_loop {}
  foreach_in_collection tpi_cell $tpi_cells {
    set is_pos [sizeof_collection [filter_collection $tpi_cell (defined(is_positive_level_sensitive)&&is_positive_level_sensitive)||(defined(is_rise_edge_triggered)&&is_rise_edge_triggered)]]

    set o_pin [get_pins -of_objects $tpi_cell -filter lib_pin_name==o]
    set d_pin [get_pins -of_objects $tpi_cell -filter lib_pin_name==d]
    set si_pin [get_pins -of_objects $tpi_cell -filter lib_pin_name==si]
    set ssb_pin [get_pins -of_objects $tpi_cell -filter lib_pin_name==ssb]

    set fanouts [all_fanout -endpoints_only -from $o_pin -quiet]
    set fanouts_cells [all_fanin -startpoints_only -flat -only_cells -to $ssb_pin -quiet]
    set is_slos 0
    set is_slos [sizeof_collection [remove_from_collection -intersect $slos_cells $fanouts_cells]]
    if {[sizeof_collection [filter_collection $fanouts full_name==[get_attribute $o_pin full_name]]] \
      && [sizeof_collection [get_timing_arcs -from $o_pin]]==0} {
      append_to_collection observe_regular $tpi_cell
      lassign [sio_maha_tpi_find_check_is_connected_to_ultiscan_prev $d_pin $tpi_cells] pos neg
      if {$is_pos && [sizeof_collection $neg]>0} {
        echo "-E-:observe_regular [get_attribute $tpi_cell full_name] POS has [sizeof_collection $neg] neg [sizeof_collection $pos] pos"
      }
      if {!$is_pos && [sizeof_collection $pos]>0} {
        echo "-E-:observe_regular [get_attribute $tpi_cell full_name] NEG has [sizeof_collection $pos] pos [sizeof_collection $neg] neg"
      }
    } elseif {[sizeof_collection [filter_collection $fanouts full_name==[get_attribute $si_pin full_name]]] && [sizeof_collection [filter_collection $fanouts full_name==[get_attribute $d_pin full_name]]] == 0} {
      append_to_collection observe_with_loop $tpi_cell
      # echo "$is_slos:[get_attribute $tpi_cell full_name]"
      lassign [sio_maha_tpi_find_check_is_connected_to_ultiscan_prev $d_pin $tpi_cells] pos neg
      if {$is_pos && [sizeof_collection $neg]>0} {
        echo "-E-:observe_with_loop [get_attribute $tpi_cell full_name] POS has [sizeof_collection $neg] neg [sizeof_collection $pos] pos"
      }
      if {!$is_pos && [sizeof_collection $pos]>0} {
        echo "-E-:observe_with_loop [get_attribute $tpi_cell full_name] NEG has [sizeof_collection $pos] pos [sizeof_collection $neg] neg"
      }
    } elseif {[sizeof_collection [filter_collection $fanouts full_name==[get_attribute $si_pin full_name]]] && [sizeof_collection [filter_collection $fanouts full_name==[get_attribute $d_pin full_name]]] && $is_slos} {
      append_to_collection control_with_loop $tpi_cell
      lassign [sio_maha_tpi_find_check_is_connected_to_ultiscan_next $o_pin $tpi_cells] pos neg
      if {$is_pos && [sizeof_collection $neg]>0} {
        echo "-E-:control_with_loop [get_attribute $tpi_cell full_name] POS has [sizeof_collection $neg] neg [sizeof_collection $pos] pos"
      }
      if {!$is_pos && [sizeof_collection $pos]>0} {
        echo "-E-:control_with_loop [get_attribute $tpi_cell full_name] NEG has [sizeof_collection $pos] pos [sizeof_collection $neg] neg"
      }
    } elseif {[sizeof_collection [filter_collection $fanouts full_name==[get_attribute $d_pin full_name]]]} {
      append_to_collection control_regular $tpi_cell
      lassign [sio_maha_tpi_find_check_is_connected_to_ultiscan_next $o_pin $tpi_cells] pos neg
      if {$is_pos && [sizeof_collection $neg]>0} {
        echo "-E-:control_regular [get_attribute $tpi_cell full_name] POS has [sizeof_collection $neg] neg [sizeof_collection $pos] pos"
      }
      if {!$is_pos && [sizeof_collection $pos]>0} {
        echo "-E-:control_regular [get_attribute $tpi_cell full_name] NEG has [sizeof_collection $pos] pos [sizeof_collection $neg] neg"
      }
    } else {
      echo "cannot categorize [get_attribute $tpi_cell full_name]"
    }
  }
  echo observe_regular:[sizeof_collection $observe_regular]
  echo observe_with_loop:[sizeof_collection $observe_with_loop]
  echo control_regular:[sizeof_collection $control_regular]
  echo control_with_loop:[sizeof_collection $control_with_loop]
  echo tpi_cells:[sizeof_collection $tpi_cells]
}

proc sio_get_tns_for_RFs_pins {outfil} {
  sio_get_tns_for_ebbs_pins $outfil "full_name=~*rfip*" "" 100 0
}

#template filter: e.g: base_name==rsintprfctop
proc sio_get_tns_for_ebbs_pins {outfile {template_filter ""} {instance_filter ""} {max_paths 1} {slack_lesser_than 0}} {
  printt "Start: [arginfo]"
  set out [open $outfile w]
  set filter "is_black_box&&number_of_pins>1&&!is_combinational"
  if {$template_filter ne ""} {
    set filter "${filter}&&${template_filter}"
  }
  set ebbs [get_cells -of_objects [get_lib_cells -of_objects [get_libs] -filter $filter]]
  set i 0
  puts $out "template,instance,pin_name,lib_pin_name,startpoint,endpoint,slack"
  parallel_foreach_in_collection ebb $ebbs {
    set ifilter !is_clock_pin&&is_data_pin
    if {$instance_filter ne ""} {
      set ifilter "${ifilter}&&${instance_filter}"
    }
    set pins [get_pins -of_objects $ebb -filter $ifilter -quiet]
    set ref_name [get_attribute $ebb ref_name]
    set ebb_name [get_attribute $ebb full_name]
    foreach_in_collection pin $pins {
      set pin_name [get_attribute $pin full_name]
      set lib_pin_name [get_attribute $pin lib_pin_name]
      set tps [get_timing_path -through $pin -start_end_pair -max_paths $max_paths -slack_lesser_than $slack_lesser_than]
      foreach_in_collection tp $tps {
        set startpoint [get_attribute $tp startpoint.full_name]
        set endpoint [get_attribute $tp endpoint.full_name]
        set slack [get_attribute $tp slack]
        post_eval {
          puts $out "$ref_name,$ebb_name,$pin_name,$lib_pin_name,$startpoint,$endpoint,$slack"
        }
      }
    }
    post_eval {
      if {![expr [incr i] % 10]} {
        printt "$i/[sizeof_collection $ebbs]"
      }
    }
  }
  close $out
  printt "Done"
}
proc sio_write_all_cells_clusters {outfile unit_cells_outfile} {
  printt "Start: [arginfo]"
  set dx 10
  set dy 10
  set min_cells_per_unit 1000
  set tag $::ivar(fct_setup_cfg,FE_COLLATERAL_TAG)
  array set all_td {}
  foreach par [lmap x [get_partitions] {lindex [split $x "/"] end}] {
    set d [lmap x [glob -nocomplain $::env(PROJ_ARCHIVE)/arc/$par/fe_collateral/${tag}/ms_units.stubs/*.v] {file tail [file rootname $x]}]
    set all_td($par) $d
  }
  printt "Tag: $tag, dx: $dx, dy: $dy, min_cells_per_unit: $min_cells_per_unit"
  printt "Data: [array get all_td]"
  set out [open $unit_cells_outfile w]
  puts $out "partition,unit,x_min,x_max,y_min,y_max,ref_name,full_name,is_sequential"
  set cells [get_cell -hierarchical -quiet]
  set needed_attributes [list x_coordinate_min x_coordinate_max y_coordinate_min y_coordinate_max is_sequential is_black_box is_negative_level_sensitive is_positive_level_sensitive is_hierarchical]
  array set matrix {}
  array set per_seq_unit {}
  foreach {par ms_units} [array get all_td] {
    set ms_units_count 0
    set cells_to_par {}
    foreach par2 [get_partitions] {
      if {![string equal $par [lindex [split $par2 "/"] end]]} {
        continue
      }
      append_to_collection cells_to_par [filter_collection $cells full_name=~$par2/*]
    }
    printt "start $par:[llength $ms_units] [sizeof_collection $cells_to_par]"
    foreach unit $ms_units {
      incr ms_units_count
      # printt "  -start Unit $unit"
      set unit_cell [filter_collection $cells_to_par ref_name=~*$unit&&is_hierarchical]
      if {[sizeof_collection $unit_cell] == 0} {
        # printt "    -Skip $unit: no unit cell"
        continue
      }
      foreach unit_name [get_attribute $unit_cell full_name] {
        # set unit_cells [filter_collection $cells_to_par full_name=~${unit_name}/*&&!is_hierarchical&&!is_black_box&&defined(x_coordinate_max)&&defined(y_coordinate_max)&&is_sequential]
        set unit_cells [filter_collection $cells_to_par full_name=~${unit_name}/*&&!is_hierarchical&&!is_black_box&&defined(x_coordinate_max)&&defined(y_coordinate_max)]
        if {[sizeof_collection $unit_cells] < $min_cells_per_unit} {
          # printt "    -Skip $unit $unit_name: [sizeof_collection $unit_cells] $ms_units_count/[llength $ms_units]"
          continue
        }
        # printt "    -unit_cells $unit $unit_name: [sizeof_collection $unit_cells] $ms_units_count/[llength $ms_units]"
        foreach_in_collection cell $unit_cells {
          set cell_x_min [expr [get_attribute $cell x_coordinate_min]/1000]
          set cell_x_max [expr [get_attribute $cell x_coordinate_max]/1000]
          set cell_y_min [expr [get_attribute $cell y_coordinate_min]/1000]
          set cell_y_max [expr [get_attribute $cell y_coordinate_max]/1000]
          set is_sequential [get_attribute $cell is_sequential]
          set full_name [get_attribute $cell full_name]
          puts $out "${par},${unit},$cell_x_min,$cell_x_max,$cell_y_min,$cell_y_max,[get_attribute $cell ref_name],${full_name},${is_sequential}"
          if {$is_sequential} {
            if {[info exists per_seq_unit($full_name)]} {
              set per_seq_unit($full_name) [list]
            }
            lappend per_seq_unit($full_name) [list $par $unit]
          }
          set x [expr int($cell_x_min/$dx)*$dx]
          set y [expr int($cell_y_min/$dy)*$dy]
          set key "$x,$y"
          if {![info exists matrix($key)]} {
            set matrix($key) [list ${par}:${unit} 1]
          } else {
            set found [lsearch -exact $matrix($key) ${par}:${unit}]
            if { $found == -1} {
              lappend matrix($key) ${par}:${unit} 1
            } else {
              lset matrix($key) [expr $found+1] [expr [lindex $matrix($key) $found+1]+1]
            }
          }
        }
      }
    }
  }
  close $out
  printt "Start write"

  set out [open $outfile w]
  puts $out "x,y,partition,unit,units_data"
  foreach {k v} [array get matrix] {
    set c 0
    set to_write ""
    foreach {vv count} $v {
      if {$count > $c} {
        set to_write [join [split $vv :] ,]
        set c $count
      }
    }
    puts $out "$k,$to_write,$v"
  }
  close $out
  printt "Done"

}

proc sio_write_all_cells_clusters_analysis_between_clusters {infile outfile} {
  printt "Start: [arginfo]"
  set no_data NA

  set in [open $infile]
  gets $in l
  set count 0
  while {[gets $in l] >= 0} {
    lassign [split $l ,] partition unit x_min x_max y_min y_max ref_name full_name is_sequential
    if {$is_sequential == "true"} {
      set per_seq_array_name($full_name) $unit
      incr count
    }
  }
  close $in

  printt "Done read $count sequential cells"
  # set pars [get_partitions]
  array set summary {}
  set i 0
  foreach {k unit} [array get per_seq_array_name] {
    if {[expr $i % 1000] == 0} {
      printt "$i/$count"
    }
    incr i
    set all_fanouts [all_fanout -endpoints_only -flat -only_cells -from ${k}/o* -quiet]
    foreach_in_collection fanout $all_fanouts {
      set fanout_cell [get_attribute $fanout full_name]
      if {$fanout_cell eq $k} {
        continue
      }
      if {![info exists per_seq_array_name($fanout_cell)]} {
        # set partition [get_partition_from_name $fanout_cell $pars]
        set per_seq_array_name($fanout_cell) $no_data
      }
      set fanout_unit $per_seq_array_name($fanout_cell)

      set key "$unit,$fanout_unit"
      if {![info exists summary($key)]} {
        set summary($key) 1
      } else {
        incr summary($key)
      }

    }
  }
  printt "Done calculate"
  set i 0
  set out [open $outfile w]
  puts $out "from_unit,to_unit,count"
  foreach {k v} [array get summary] {
    puts $out "$k,$v"
    incr i
  }
  close $out
  printt "Done $i clusters"

}

proc pteco_check_meu_meu {report_file} {
  set in [open $report_file]
  set path_id -1
  set next_from 0
  set next_to 0
  set clk_to ""
  set clk_from ""
  set start_table 0
  set last_line ""
  set out [open ${report_file}.out w]
  while {[gets $in l] >= 0} {
    if {[string equal -l 8 $l "Path id "]} {
      if {$path_id >-1} {
        puts $out "$path_id,$clk_from,$clk_to,$pin_start,$template_start,$pin_end,$template_end"
      }
      set path_id [lindex $l 2]
      set next_to 0
      set next_from 0
    } elseif {$next_to} {
      set next_to 0
      set next_from 0
      set clk_to [string trim $l]
    } elseif {$next_from} {
      set next_to 0
      set next_from 0
      set clk_from [string trim $l]
    } elseif {[string equal -l 6 $l "From: "]} {
      set next_to 0
      set next_from 1
    } elseif {[string equal -l 4 $l "To: "]} {
      set next_to 1
      set next_from 0
    } elseif {[string equal -l 4 $l "Id |"]} {
      set start_table 1
    } elseif {$start_table == 2} {
      set ll [split [string map {{ } {}} $l] "|"]
      set pin_start [lindex $ll 5]
      set template_start [lindex $ll end]
      set start_table 3
    } elseif {$start_table == 1 && [string equal -l 3 $l "---"]} {
      set start_table 2
    } elseif {$start_table == 3 && [string trim $l] eq ""} {
      set ll [split [string map {{ } {}} $last_line] "|"]
      set pin_end [lindex $ll 5]
      set template_end [lindex $ll end]
      set start_table 0
    }
    set last_line $l
  }
  close $in
  set ll [split [string map {{ } {}} $last_line] "|"]
  set pin_end [lindex $ll 5]
  set template_end [lindex $ll end]
  puts $out "$path_id,$clk_from,$clk_to,$pin_start,$template_start,$pin_end,$template_end"
  close $out
}

proc sio_check_abbutted_pins {ports_from_spef_files outfile} {
  array set data_from_spef {}
  foreach f $ports_from_spef_files {
    set in [open $f]
    set i 0
    array set header [list]
    set lines [list]
    gets $in line
    foreach l [split $line ,] {
      set header($l) $i
      incr i
    }
    while {[gets $in line] >= 0} {
      set id 0
      foreach ll [split $line ,] {
        set linel($id) $ll
        incr id
      }
      set data_from_spef($linel($header(inst_name))) [list $linel($header(x_inst)) $linel($header(y_inst))]
    }
    close $in
  }
  set out [open $outfile w]
  set blocks [get_partitions]
  set pins [get_pins -of_objects $blocks -filter {direction=~in*}]
  puts $out "pin_name,pin_name_abutted,x,y,x_abutted,y_abutted,x_spef,y_spef,x_abutted_spef,y_abutted_spef,manh_dist_spef"
  foreach_in_collection pin $pins {
    set pin_name [get_attribute $pin full_name]
    set direction [get_attribute $pin direction -quiet]
    set x [get_attribute $pin x_coordinate -quiet]
    set y [get_attribute $pin y_coordinate -quiet]
    if {$x ne ""} {
      set x [expr $x/1000]
    }
    if {$y ne ""} {
      set y [expr $y/1000]
    }
    set abutted_port [get_abutted_port $pin_name $blocks]
    set x_abutted ""
    set y_abutted ""
    set spef_abutted ","
    if {$abutted_port ne ""} {
      set x_abutted [get_attribute $pin x_coordinate -quiet]
      set y_abutted [get_attribute $pin y_coordinate -quiet]
      if {$x_abutted ne ""} {
        set x_abutted [expr $x_abutted/1000]
      }
      if {$y_abutted ne ""} {
        set y_abutted [expr $y_abutted/1000]
      }
      if {[info exists data_from_spef($abutted_port)]} {
        set spef_abutted [join $data_from_spef($abutted_port) ,]
      }
    }
    set spef ","
    if {[info exists data_from_spef($pin_name)]} {
      set spef [join $data_from_spef($pin_name) ,]
    }
    set manh_dist_spef ""
    if {$spef_abutted ne "," && $spef ne ","} {
      lassign $data_from_spef($abutted_port) x_abutted_spef y_abutted_spef
      lassign $data_from_spef($pin_name) x_spef y_spef
      try {
        set manh_dist_spef [expr abs($x_spef-$x_abutted_spef)+abs($y_spef-$y_abutted_spef)]
      }
    }
    puts $out "$pin_name,$abutted_port,$x,$y,$x_abutted,$y_abutted,$spef,$spef_abutted,$manh_dist_spef"
  }
  close $out
}

proc sio_write_all_cells {outfile} {
  set out [open $outfile w]
  puts $out "base_name,cell_leakage_power,always_on,number_of_pins,count"
  set all_lib_cells  [get_lib_cells -of_objects [get_libs] -filter {is_instantiated==true}]
  foreach_in_collection lib_cell $all_lib_cells {
    set base_name [get_attribute $lib_cell base_name]
    set cell_leakage_power [get_attribute $lib_cell cell_leakage_power]
    set always_on [get_attribute $lib_cell always_on]
    set number_of_pins [get_attribute $lib_cell number_of_pins]
    set count [sizeof_collection [get_cells -of_objects $lib_cell]]
    puts $out "$base_name,$cell_leakage_power,$always_on,$number_of_pins,$count"
  }
  close $out
}

proc sio_write_seq_to_seq_data_one_pin_fast {pin_name} {
  set ret [list]
  set pin [get_pins $pin_name -quiet]
  if {[sizeof_collection $pin] == 0} {
    return $ret
  }
  set fanouts [all_fanout -endpoints_only -flat -from $pin -quiet]
  if {[sizeof_collection $fanouts] == 0} {
    return $ret
  }
  set startpoint_name [get_attribute $pin full_name]
  set startpoint_cell_name [get_attribute $pin cell.full_name -quiet]
  set from_cluster $startpoint_cell_name
  set lpn ""
  if {[get_attribute $pin object_class] eq "pin"} {
    set lpn [get_attribute $pin lib_pin_name]
  }
  if {[string match "*MBIT*" $pin_name] } {
    if {[string equal -length 1 "o" $lpn] || [string equal -length 1 "Q" $lpn] || [string equal -nocase -length 1 "d" $lpn]} {
      set from_cluster_compress [compress_pin_name [sio_mow_mbit_get_relevant $pin_name]]
    } else {
      set from_cluster_compress [sio_mow_mbit_compress_pin_name [compress_pin_name $startpoint_cell_name]]
    }
  } else {
    set from_cluster_compress [compress_pin_name $from_cluster]
  }
  set x_out [get_attribute $pin cell.x_coordinate_min -quiet]
  set y_out [get_attribute $pin cell.y_coordinate_min -quiet]

  foreach_in_collection endpoint $fanouts {
    set endpoint_name [get_attribute $endpoint full_name]
    set endpoint_cell_name [get_attribute $endpoint cell.full_name -quiet]
    set to_cluster $endpoint_cell_name
    set lpn ""
    if {[get_attribute $endpoint object_class] eq "pin"} {
      set lpn [get_attribute $endpoint lib_pin_name]
    }
    if {[string match "*MBIT*" $endpoint_name] } {
      if { ([string equal -length 1 "o" $lpn] || [string equal -length 1 "Q" $lpn] || [string equal -nocase -length 1 "d" $lpn])} {
        set to_cluster_compress [compress_pin_name [sio_mow_mbit_get_relevant $endpoint_name]]
      } else {
        set to_cluster_compress [sio_mow_mbit_compress_pin_name [compress_pin_name $endpoint_cell_name]]
      }
    } else {
      set to_cluster_compress [compress_pin_name $to_cluster]
    }
    set x [get_attribute $endpoint x_coordinate -quiet]
    set y [get_attribute $endpoint y_coordinate -quiet]
    lappend ret "$startpoint_name,$startpoint_cell_name,$x_out,$y_out,$endpoint_name,$endpoint_cell_name,$x,$y,$from_cluster_compress,$to_cluster_compress"
  }
  return $ret
}
# icore0/par_exe/rs_vec_wrap/rsvecbpd/auto_vector_MBIT_PtPwrUpM301H_reg_6__MBIT_PtPwrUpM301H_reg_5__MBIT_PtPwrUpM301H_reg_4__MBIT_PtPwrUpM301H_reg_3_
proc sio_mow_mbit_compress_pin_name {pin_name} {
  array set compressed_names {}
  set ret ""
  set a [split $pin_name "/"]
  if {[string equal -length 12 "auto_vector_" [lindex $a end]]} {
    set ret auto_vector
    set mbits [split [lindex $a end] "_"]
    set aa ""
    set start 0
    foreach mbit $mbits {
      if {$mbit eq "MBIT"} {
        if {![info exists compressed_names($aa)] && $aa ne ""} {
          append ret _ MBIT _ $aa
        }
        set compressed_names($aa) 1
        set aa ""
        set start 1
      } elseif {$start} {
        append aa _ ${mbit}
      }
    }
    if {![info exists compressed_names($aa)] && $aa ne ""} {
      append ret _ MBIT _ $aa
    }
  }
  return [join [lrange $a 0 end-1] /]/$ret
}
proc sio_write_seq_to_seq_data_one_pin {pin_name} {
  set ret [list]
  set pin [get_pins $pin_name -quiet]
  if {[sizeof_collection $pin] == 0} {
    return $ret
  }
  set fanouts [all_fanout -endpoints_only -flat -from $pin -quiet]
  if {[sizeof_collection $fanouts] == 0} {
    return $ret
  }
  set pin_name [get_attribute $pin full_name]
  set pin_cell_name [get_attribute $pin cell.full_name -quiet]
  set from_cluster $pin_cell_name
  set lpn [get_attribute $pin lib_pin_name]
  if {[string match "*MBIT*" $pin_name] && ([string equal -length 1 "o" $lpn] || [string equal -length 1 "Q" $lpn] || [string equal -nocase -length 1 "d" $lpn])} {
    set from_cluster [sio_mow_mbit_get_relevant $pin_name]
  }
  set x_out [get_attribute $pin cell.x_coordinate_min -quiet]
  set y_out [get_attribute $pin cell.y_coordinate_min -quiet]
  foreach_in_collection endpoint $fanouts {
    set tp [get_timing_path -through $pin -to $endpoint]
    set x [get_attribute $endpoint cell.x_coordinate_min -quiet]
    set y [get_attribute $endpoint cell.y_coordinate_min -quiet]
    set slack [get_attribute $tp slack]
    set normalized_slack [get_attribute $tp normalized_slack]
    set path_group [get_attribute $tp path_group.full_name -quiet]
    set npoints [sizeof_collection [get_attribute $tp points -quiet]]
    set sum_transit_time [lsum [get_attribute $tp points.transition -quiet]]
    set required [get_attribute $tp required -quiet]
    set endpoint_name [get_attribute $endpoint full_name]
    set endpoint_cell_name [get_attribute $endpoint cell.full_name -quiet]
    set to_cluster $endpoint_cell_name
    if {[string match "*MBIT*" $endpoint_name] } {
      set to_cluster [sio_mow_mbit_get_relevant $endpoint_name]
    }
    set startpoint_clock [get_attribute $tp startpoint_clock.full_name -quiet]
    set endpoint_clock [get_attribute $tp endpoint_clock.full_name -quiet]
    set startpoint [get_attribute $tp startpoint.full_name -quiet]
    set num_pins2 [sizeof_collection [filter_collection [get_attribute $tp points.object] {defined(cell)&&defined(direction)&&direction==out&&cell.number_of_pins==2}]]
    lappend ret "$pin_name,$pin_cell_name,$startpoint,$startpoint_clock,$x_out,$y_out,$endpoint_name,$endpoint_cell_name,$endpoint_clock,$x,$y,$slack,$normalized_slack,$path_group,$npoints,$sum_transit_time,$required,$num_pins2,$from_cluster,$to_cluster"
  }
  return $ret
}

proc sio_write_seq_to_seq_data {outfile {filter "(full_name=~icore0/par_*||full_name=~par_*/*)"}} {
  printt "Start: [arginfo]"
  set tofilter cell.is_sequential&&direction==out
  if {$filter ne ""} {
    append tofilter && ${filter}
  }
  set all_out_seq_pins [get_pins -filter $tofilter -hierarchical -quiet]
  set out [open $outfile w]
  set count 0
  puts $out "startpoint,startpoint_cell_name,startpoint_x,startpoint_y,endpoint,endpoint_cell_name,endpoint_x,endpoint_y,from_cluster,to_cluster"
  foreach_in_collection pin $all_out_seq_pins {
    if {[expr [incr count] % 10000] == 0} {
      printt "$count/[sizeof_collection $all_out_seq_pins]"
    }
    foreach l [sio_write_seq_to_seq_data_one_pin_fast $pin] {
      puts $out [join $l \n]
    }
  }
  close $out
}
proc check_path_is_uarch_paths {paths} {
  foreach_in_collection path $paths {
    set uarch [_check_path_is_uarch_one_path $path]
    if {$uarch ne ""} {
      return $uarch
    }
  }
}

proc _check_path_is_uarch_one_path {path} {
  global _sio_uarchs_patterns
  check_path_is_uarch_get_uarch_patterns

  if {![array size _sio_uarchs_patterns]} {
    return ""
  }
  set path_startpoint [get_attribute $path startpoint.full_name]
  set path_startpoint_clock [get_attribute $path startpoint_clock.full_name]
  set path_endpoint [get_attribute $path endpoint.full_name]
  set path_endpoint_clock [get_attribute $path endpoint_clock.full_name]
  if {[info exists _sio_uarchs_patterns(${path_startpoint_clock},${path_endpoint_clock})]} {
    set patterns $_sio_uarchs_patterns(${path_startpoint_clock},${path_endpoint_clock})
  } else {
    return ""
  }
  foreach ppp $patterns {
    # set pattern(rcv_signal) $rl
    # set pattern(drv_signal) $dl
    # set pattern(family)
    # set pattern(startpoint) $dc
    # set pattern(endpoint) $rc
    # lappend _sio_uarchs_patterns [list [lindex $fields $headers_i(family)] $dc $rc $dl $rl]
    lassign $ppp family drv_signal rcv_signal drv_par rcv_par
    set m [expr [string match "${drv_par}/*" $path_startpoint] && [string match "${rcv_par}/*" $path_endpoint]]

    if {$m} {
      set m [sizeof_collection [filter_collection [get_attribute $path points.object] object_class==pin&&is_hierarchical&&full_name=~$drv_signal]]
    }
    if {$m} {
      set m [sizeof_collection [filter_collection [get_attribute $path points.object] full_name=~$rcv_signal]]
      return $family
    }
  }
  return ""
}

proc check_path_is_uarch_get_uarch_patterns {} {
  global _sio_uarchs_patterns
  if {[info exists _sio_uarchs_patterns]} {
    return
  }
  foreach p [get_partitions] {
    set partitions([string map {icore0 icore? icore1 icore?} $p]) 1
  }

  set product_name $::ivar(envs,CHOP)
  set block $::ivar(design_name)
  set f ""
  if {[string match "GFCN2*" $product_name]} {
    set f /nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/gfc_servera0/gfc_uarch_list.csv
  } elseif {[string match "PNC78*" $product_name]} {
    set f /nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/pnc_uarch_list.csv
  }
  array set _sio_uarchs_patterns {}
  if {$f eq ""} {
    printt "-E-:check_path_is_uarch_get_uarch_patterns: no file for $product_name"
    return
  }
  printt "Using uarch patterns file: $f"
  set in [open $f]
  gets $in header
  set i 0
  foreach l [split $header ,] {
    set headers($i) [string map {# ""} $l]
    set headers_i([string map {# ""} $l]) $i
    incr i
  }
  while {[gets $in l] >= 0} {
    set fields [split $l ,]
    if {[llength $fields] != [llength [array names headers_i]]} {
      printt "-E-:check_path_is_uarch_get_uarch_patterns: invalid line in $f: $l"
      continue
    }
    set i 0
    #family startpoint drv_par drv_signal rcv_par rcv_signal endpoint pba
    set drv_signal {}
    set rcv_signal {}
    set dpars {}
    set rpars {}
    foreach p [array names partitions] {
      set pp [lindex [split $p /] end]
      if {[string match [lindex $fields $headers_i(drv_par)] $pp] } {
        lappend drv_signal [list ${p} ${p}/*[lindex $fields $headers_i(drv_signal)]*]
      }
      if {[string match [lindex $fields $headers_i(rcv_par)] $pp] } {
        lappend rcv_signal [list ${p} ${p}/*[lindex $fields $headers_i(rcv_signal)]*]
      }
    }
    if {[llength $rcv_signal] == 0 || [llength $drv_signal] == 0} {
      printt "-E-:check_path_is_uarch_get_uarch_patterns: invalid drv_signal or rcv_signal in $f: $l"
      continue
    }
    foreach dc [get_attribute [get_clocks [lindex $fields $headers_i(startpoint)]] full_name] {
      foreach rc [get_attribute [get_clocks [lindex $fields $headers_i(endpoint)]] full_name] {
        foreach dd $drv_signal {
          foreach rr $rcv_signal {
            lassign $dd dp dl
            lassign $rr rp rl
            # array set pattern {}
            # set pattern(rcv_signal) $rl
            # set pattern(drv_signal) $dl
            # set pattern(family)
            # set pattern(startpoint) $dc
            # set pattern(endpoint) $rc
            lappend _sio_uarchs_patterns(${dc},${rc}) [list [lindex $fields $headers_i(family)] $dl $rl $dp $rp]
          }
        }
      }
    }
  }
  close $in
}
proc sio_mow_center_of_mass {points} {
  #set points {
  #     {1.0 2.0}
  #     {3.0 4.0}
  #     {5.0 0.0}
  # }
  # set points {
  #     {1.0 2.0 1.0}
  #     {3.0 4.0 2.0}
  #     {5.0 0.0 1.0}
  # }

  # Initialize weighted sums
  set sumWX 0.0
  set sumWY 0.0
  set totalWeight 0.0

  foreach pt $points {
    lassign $pt x y w
    if {$w eq ""} {
      set w 1.0  ;# Default weight if not specified
    }
    set sumWX [expr {$sumWX + $x * $w}]
    set sumWY [expr {$sumWY + $y * $w}]
    set totalWeight [expr {$totalWeight + $w}]
  }

  set centroidX [expr {$sumWX / $totalWeight}]
  set centroidY [expr {$sumWY / $totalWeight}]

  return [list $centroidX, $centroidY]
}

proc dft_wall {fout} {
  #source /nfs/site/disks/ayarokh_wa/git/bei/sio/tcl/sio_common.tcl
  # dft_wall dft_wall.max_high.before.csv
  set fin /nfs/site/disks/ayarokh_wa/pteco/runs/PNCA0/core_client_250910_ww36_A0_SETUP_FIX/all_seq_to_run
  set in [open $fin]
  set out [open $fout w]
  puts $out "point,slack,startpoint,endpoint,startpoint_clock,endpoint_clock"
  while {[gets $in l] >= 0} {
    set tp [get_timing_path -to $l -pba_mode exhaustive -slack_lesser_than 1000 -max_paths 1 -delay_type [sio_mow_get_delay_type]]
    set slack [get_attribute $tp slack]
    set startpoint [get_attribute $tp startpoint.full_name]
    set endpoint [get_attribute $tp endpoint.full_name]
    set startpoint_clock [get_attribute $tp startpoint_clock.full_name]
    set endpoint_clock [get_attribute $tp endpoint_clock.full_name]
    puts $out "$l,$slack,$startpoint,$endpoint,$startpoint_clock,$endpoint_clock"
  }
  close $out
  close $in
}

proc sio_check_specs_that_overlapped {} {
  set partitions [get_partitions]
  set ports [get_pins -of_objects $partitions]
  # set ports [get_pins {icore0/par_ooo_vec/moatretdispm806h icore0/par_ooo_vec/rortptr_clken_m902h}]
  array set data {}
  array set flop_to_port {}
  set count 0
  set out [open sio_check_specs_that_overlapped.csv w]
  puts $out "port,flop,direction,spec,logic_count,slack,x_coordinate,y_coordinate"
  foreach_in_collection port $ports {
    if {[expr $count % 100000] == 0} {
      printt "$count/[sizeof_collection $ports]"
    }
    incr count
    set x_port [get_attribute $port x_coordinate -quiet]
    set y_port [get_attribute $port y_coordinate -quiet]
    if {[get_attribute $port direction] eq "in"} {
      set fans [all_fanout -endpoints_only -flat -from $port -only_cells -quiet]
    } else {
      set fans [all_fanin -startpoints_only -flat -to $port -only_cells -quiet]
    }
    foreach_in_collection fan $fans {
      set x_fan [get_attribute $fan x_coordinate_min -quiet]
      set y_fan [get_attribute $fan y_coordinate_min -quiet]
      set n [get_attribute $fan full_name]
      set p [get_attribute $port full_name]
      set par_port [get_partition_from_name $p $partitions]
      set fan_port [get_partition_from_name $n $partitions]
      if {$par_port eq $fan_port} {
        set kye "$p,$n"
        set data($kye) 1
        lappend flop_to_port($n) $p
      }
    }
  }
  foreach {n p} [array get flop_to_port] {
    if {[llength $p] > 1} {
      foreach pp $p {
        set spec [sio_mow_get_pin_spec [set pin [get_pins $pp]]]
        set tp {}
        set direction [get_attribute [get_pins $pp] direction]
        if {$direction eq "in"} {
          set tp [get_timing_path -through $pp -through $n -max_paths 1 -slack_lesser_than 1000 -include_hierarchical_pins]
        } else {
          set tp [get_timing_path -through $n -through $pp -max_paths 1 -slack_lesser_than 1000 -include_hierarchical_pins]
        }
        set points [index_collection [get_attribute $tp points] 1 end-1]
        set start [expr {$direction ne "in"}]
        set logic_count 0
        foreach_in_collection point $points {
          set point_name [get_attribute $point object.full_name]
          if {$start && ([string equal $point_name $pp] || [string equal $point_name [get_attribute $point object.cell.full_name]])} {
            break
          }
          if {$start && (! [get_attribute $point object.is_hierarchical] && ([get_attribute $point object.direction] eq "in" &&[check_regexs_buffs_invs [get_attribute $point object.cell.ref_name]]))} {
            incr logic_count
          }
          if {!$start && [string equal $point_name $pp]} {
            set start 1
          }
        }
        puts $out "$pp,$n,$direction,$spec,$logic_count,[get_attribute $tp slack],[expr [get_attribute $pin x_coordinate]/1000],[expr [get_attribute $pin y_coordinate]/1000]"
      }
    }
  }
  close $out
}

proc get_logic_dist_from_ports_for_Allouche {outfile} {
  set pins [get_pins -filter {direction==in&&is_hierarchical&&launch_clocks.full_name=~mclk_*} {icore0/par_*/* par*} -quiet]
  set out [open $outfile w]
  puts $out "port,port_abutted,x_port,y_port,logic_to_abutted,logic_to_abutted_ref_name,logic_to_abutted_x_cell,_logic_to_abutted_y_cell,cell_from_port,cell_from_port_ref,cell_from_port_x,cell_from_port_y,start_point,end_point,slack"
  set count 0
  foreach_in_collection pin $pins {
    if {[expr [incr count] % 1000] == 0} {
      printt "$count/[sizeof_collection $pins]"
    }
    set pin_name [get_attribute $pin full_name]
    set x_port [expr [get_attribute $pin x_coordinate]/1000]
    set y_port [expr [get_attribute $pin y_coordinate]/1000]
    set tp [get_timing_path -through $pin -include_hierarchical_pins -slack_lesser_than 1000]
    set port1 ""
    set port_abutted ""
    set cell1 ""
    set cell2 ""
    set prev ""
    foreach_in_collection pin_point [filter_collection [get_attribute $tp points] object.cell.ref_name!~INV*&&object.cell.ref_name!~BUF*] {
      if {[get_attribute $pin_point object.full_name] eq $pin_name} {
        set port1 [get_attribute $prev object.full_name]
        set port_abutted [get_attribute $pin_point object.full_name]
      }
      set prev $pin_point
      if {![get_attribute $pin_point object.is_hierarchical]} {
        if {$port_abutted eq ""} {
          set cell1 "[get_attribute $pin_point object.cell.full_name],[get_attribute $pin_point object.cell.ref_name],[get_attribute $pin_point x_coordinate],[get_attribute $pin_point y_coordinate]"
        } else {
          set cell2 "[get_attribute $pin_point object.cell.full_name],[get_attribute $pin_point object.cell.ref_name],[get_attribute $pin_point x_coordinate],[get_attribute $pin_point y_coordinate]"
          break
        }
      }
    }
    puts $out "$port1,$pin_name,$x_port,$y_port,$cell1,$cell2,[get_attribute $tp startpoint.full_name],[get_attribute $tp endpoint.full_name],[get_attribute $tp slack]"
  }
  close $out
}
proc get_logic_dist_from_ports_for_Allouche_fanout {fanout pin x_port y_port} {
  set all_fanout_by_seq [filter_collection [all_fanout -flat -from $pin -to $fanout -only_cells -quiet] ref_name!~INV*&&ref_name!~BUF*&&full_name!~*/DIODE*]
  #find minimal distance cell from port
  set all_distances {}
  set min_distance 1000000000
  set data {}
  foreach_in_collection fcell $all_fanout_by_seq {
    set x_cell [expr [get_attribute $fcell x_coordinate_min]/1000]
    set y_cell [expr [get_attribute $fcell y_coordinate_min]/1000]
    set logic_distance [expr abs($x_port - $x_cell) + abs($y_port - $y_cell)]
    if {$logic_distance < $min_distance} {
      set min_distance $logic_distance
      set data [list [get_attribute $fcell full_name] [get_attribute $fcell ref_name] $x_cell $y_cell $logic_distance]
    }
  }
  return $data
}

proc sio_mow_get_interface_ooo_vec {outfile} {
  printt "Start: [arginfo]"
  set debug 0
  set pars  [get_partitions]
  set out [open $outfile w]
  puts $out "port1,direction1,port2,direction2,x_port1,y_port1,x_port2,y_port2,slack"
  set ports [get_pins icore0/par_ooo_vec/* -filter {full_name!=*FEEDTHRU*}]
  if {$debug} {
    printt "Debug mode: limit ports to 10"
    set ports [index_collection $ports 0 10]
  }
  set count 0
  array set seen {}
  array set done {}
  foreach_in_collection port $ports {
    if {[expr [incr count] % 1000] == 0} {
      printt "$count/[sizeof_collection $ports]"
    }
    set direction [get_attribute $port direction]
    if {$direction eq "in"} {
      set all_fanins [all_fanin -startpoints_only -flat -to $port]
    } else {
      set all_fanins [all_fanout -endpoints_only -flat -from $port]
    }
    foreach_in_collection fin $all_fanins {
      if {[get_attribute $fin cell.is_black_box] ne "" && ![get_attribute $fin cell.is_black_box]} {
        set fin_cell [get_cells -of_objects $fin]
      }
      set key2 "[get_attribute $port full_name],[get_attribute $fin full_name]"
      if {[info exists done($key2)]} {
        continue
      }
      set done($key2) 1
      set partition [get_partition_from_name [get_attribute $fin full_name] $pars]
      if {$direction eq "in"} {
        if {[get_attribute $fin lib_pin_name] eq "CP"} {
          set tp [get_timing_path -from $fin -through $port -include_hierarchical_pins]
          set pin [index_collection [filter_collection [get_attribute $tp points.object] full_name=~${partition}*&&direction==out&&is_hierarchical] end]
        } else {
          set tp [get_timing_path -through $fin_cell -through $port -include_hierarchical_pins]
          set pin [index_collection [filter_collection [get_attribute $tp points.object] full_name=~${partition}*&&direction==out&&is_hierarchical] 0]
        }
      } else {
        set tp [get_timing_path -to $fin -through $port -include_hierarchical_pins]
        set pin [index_collection [filter_collection [get_attribute $tp points.object] full_name=~${partition}*&&direction==in&&is_hierarchical] 0]
      }
      if {$pin eq ""} {
        printt "-E-:sio_mow_get_interface_ooo_vec: cannot find pin in path for port [get_attribute $port full_name]: [get_attribute $fin full_name] : $direction"
        continue
      }
      set slack [get_attribute $tp slack]
      set key "[get_attribute $pin full_name],[get_attribute $port full_name]"
      if {[info exists seen($key)]} {
        continue
      }
      if {[catch {
        set x_port1 [expr [get_attribute $pin x_coordinate]/1000]
        set y_port1 [expr [get_attribute $pin y_coordinate]/1000]
      } err]} {
        # printt "-E-:sio_mow_get_interface_ooo_vec: cannot get coordinates for pin [get_attribute $pin full_name]: $err"
        set x_port1 ""
        set y_port1 ""
      }
      if {[catch {
        set x_port2 [expr [get_attribute $port x_coordinate]/1000]
        set y_port2 [expr [get_attribute $port y_coordinate]/1000]
      } err]} {
        # printt "-E-:sio_mow_get_interface_ooo_vec: cannot get coordinates for pin [get_attribute $port full_name]: $err"
        set x_port2 ""
        set y_port2 ""
      }
      set seen($key) 1
      puts $out "[get_attribute $pin full_name],[get_attribute $pin direction],[get_attribute $port full_name],[get_attribute $port direction],$x_port1,$y_port1,$x_port2,$y_port2,$slack"
    }
  }
  close $out
}

proc sio_mow_vec_sio2po {} {
  set ports { \
    mosnoopexternalstallm901h \
      mospec4widem901h \
      rortstincm903h[*] \
      rsearlycancelwbldm804h[*] \
      rortldincm903h[*] \
      if2robsmcsnprspmnn4h_*__*__snoophit \
      rodcsdbchktagfaultm805h_*_ \
      jeclearm805h \
      roifbitm906h \
      pdptimerpulsemn5h \
      rsneedsbitm302h_9_8_[*] \
      rsneedsbitm302h_*_ \
      rortcscolorm906h \
      rortswpgs_gm905h \
      rsv2ipdstm302h_*__9_0_[*] \
      rsv2ipdstvm302h_1_0_[*] \
      rorsllbrobidm297h* \
      rorsllbrobidwrapm297h* \
      rsbrrobidvpm803h_* \
      roinhibitpsvrstrm3n3h* \
    }
    foreach port $ports {
    set pin [get_pins icore0/par_ooo_vec/$port -quiet]
  if {[sizeof_collection $pin] == 0} {
    printt "-E-:sio_mow_vec_sio2po: pin not found: icore0/par_ooo_vec/$port"
    continue
  }
  set tp [get_timing_path -through $pin -include_hierarchical_pins -max_paths 1 -slack_lesser_than 1000]
  printt "[get_attribute $tp slack] $port"
}
}

proc __test_clusters {} {
  set fin /nfs/site/disks/ayarokh_wa/GFC/SIO/GFC_CLIENT_25ww46a_ww48_1_pm_fix-FCT25WW48D_WW48_day4_contour46-CLK016.bu_postcts/VEC.sio_write_seq_to_seq_data.csv.gz
  array set from_clusters {}
  array set to_clusters {}
  array set from_clusters_no_end {}
  array set to_clusters_no_end {}
  set in [open_file $fin]
  set count 0
  while {[gets $in line] >= 0} {
    if {[expr [incr count] % 1000000] == 0} {
      printt "$count"
    }
    set fields [split $line ,]
    lassign $fields startpoint startpoint_cell_name startpoint_x startpoint_y endpoint endpoint_cell_name endpoint_x endpoint_y from_cluster to_cluster
    set from_cluster_splitted [split $from_cluster /]
    set to_cluster_splitted [split $to_cluster /]
    foreach t $from_cluster_splitted {
      if {[info exists from_clusters($t)]} {
        incr from_clusters($t)
      } else {
        set from_clusters($t) 1
      }
    }
    foreach t $to_cluster_splitted {
      if {[info exists to_clusters($t)]} {
        incr to_clusters($t)
      } else {
        set to_clusters($t) 1
      }
    }
    foreach t [lrange $from_cluster_splitted 0 end-1] {
      if {[info exists from_clusters_no_end($t)]} {
        incr from_clusters_no_end($t)
      } else {
        set from_clusters_no_end($t) 1
      }
    }
    foreach t [lrange $to_cluster_splitted 0 end-1] {
      if {[info exists to_clusters_no_end($t)]} {
        incr to_clusters_no_end($t)
      } else {
        set to_clusters_no_end($t) 1
      }
    }
  }
  close $in
  printt "Clusters: [llength [array names from_clusters]]"
  printt "Clusters: [llength [array names to_clusters]]"
  printt "Clusters: [llength [array names from_clusters_no_end]]"
  printt "Clusters: [llength [array names to_clusters_no_end]]"
  return [list [array get from_clusters] [array get to_clusters] [array get from_clusters_no_end] [array get to_clusters_no_end]]
}

proc sio_mow_pceco_read_unfixable {files outfile} {
  array set start_end_points {}
  array set stats {}
  foreach f $files {
    set done 0
    set name [file tail [file dirname $f]]
    printt "Reading file: $f"
    set startpoint_a 0
    set endpoint_a 0
    set path_id -1
    set in [open_file $f]
    while {[gets $in line] >= 0} {
      set line [string trim $line]
      if {[string match "#*" $line] || $line eq ""} {
        continue
      }
      if {$startpoint_a} {
        set startpoint_clock [string map {\( {} \) {}} [string trim $line]]
        set startpoint_a 0
      }
      if {$endpoint_a} {
        set endpoint_clock [string map {\( {} \) {}} [string trim $line]]
        set endpoint_a 0
      }
      if {$done} {
        set key "${startpoint},${endpoint}"
        set key2 "$startpoint_clock,$endpoint_clock"
        if {![info exists start_end_points($key)]} {
          set start_end_points($key) {}
          if {![info exists stats($key2)]} {
            set stats($key2) 0
          }
          incr stats($key2)
        }
        lappend start_end_points($key) [list $slack $startpoint_clock $endpoint_clock {*}$cnd $name $path_id]
        set done 0
      }
      if {[string equal -length 5 $line "Point"]} {
        # find where string Path ends
        set path_header_index [expr [string first "Path" $line] +3]
      }
      if {[string equal -length 19 $line "clock network delay"]} {
        set i $path_header_index
        while {$i >= 0} {
          if {[string index $line $i] eq " "} {
            incr i
            break
          }
          incr i -1
        }
        # echo "1:string range $i $path_header_index '[string range $line $i $path_header_index]'"

        set c [expr [string trim [string range $line $i $path_header_index]]*1000]
        lappend cnd $c
      }
      if {[string equal -length 10 $line "Startpoint"]} {
        set startpoint [string map {icore0 icore* icore1 icore*} [string trim [lindex [split $line :] 1]]]
        set startpoint_a 1
      }
      if {[string equal -length 8 $line "Path Ct:"]} {
        set path_id [string trim [lindex [split $line :] 1]]
      }
      if {[string equal -length 8 $line "Endpoint"]} {
        set cnd {}
        set endpoint [string map {icore0 icore* icore1 icore*} [string trim [lindex [split $line :] 1]]]
        set endpoint_a 1
      }
      if {[string equal -length 5 $line "slack"]} {
        set i $path_header_index
        while {$i >= 0} {
          if {[string index $line $i] eq " "} {
            incr i
            break
          }
          incr i -1
        }
        # echo "2:string range $i $path_header_index '[string range $line $i $path_header_index]'"

        set slack [expr [string range $line $i $path_header_index]*1000]
        set done 1
      }
    }
    close $in
  }
  puts "startclock,endclock,count"
  foreach {k v} [lsort -stride 2 -index 1 -integer -decreasing [array get stats]] {
    puts "$k,$v"
  }
  set data {}
  foreach {k v} [array get start_end_points] {
    foreach vv $v {
      lappend data "[lindex $vv 0] $k,[join $vv ,]"
    }
  }
  set out [open $outfile w]
  puts $out "startpoint,endpoint,slack,startpoint_clock,endpoint_clock,clock_network_delay_SP,clock_network_delay_EP,name,path_id"
  foreach l [lsort -index 0 -real $data] {
    puts $out [lindex $l 1]
  }
  close $out
}

proc sio_check_if_can_bound_path {paths max_latency {debug 0}} {
  set ret {}
  set partitions [get_partitions]
  foreach_in_collection path $paths {
    set slack [get_attribute $path slack]
    if {$slack eq ""} {
      printt "-E-:sio_check_if_can_bound: cannot get slack for pin: [get_attribute $pin full_name]"
      continue
    }
    array set can_borrow [get_to_and_from_from_tp $path]
    array set can_borrow_prev $can_borrow(prev)
    array set can_borrow_next $can_borrow(next)
    if {($can_borrow_next(max_slack) == "" || $can_borrow_next(max_slack) == INFINITY) && [get_attribute $path endpoint.lib_pin_name] eq "E"} {
      lassign [sio_icg_check [get_cells -of_objects [get_attribute $path endpoint]]] can_borrow_next(max_slack) count_icg_cells
      printt "USE ICG min slack of all fanouts: count of fanouts of icg: $count_icg_cells"
    }
    printt_debug "Path slack: prev:$can_borrow_prev(max_slack) next:$can_borrow_next(max_slack) " $debug
    set startpoint [get_attribute $path startpoint.full_name]
    set endpoint [get_attribute $path endpoint.full_name]
    set partition_start [get_partition_from_name $startpoint $partitions]
    set partition_end [get_partition_from_name $endpoint $partitions]

    lassign [sio_check_if_can_bound_clk_latency $path $max_latency $debug] start_clk_latency_borrow end_clk_latency_borrow
    printt_debug "Clock latency borrow: start $start_clk_latency_borrow end $end_clk_latency_borrow" $debug
    set logic_bound [sio_check_if_can_bound_logic_nearest_logic $path $partition_start 0 $debug]
    printt_debug "Logic bound: $logic_bound" $debug
    set logic_bound_rev [sio_check_if_can_bound_logic_nearest_logic $path $partition_end 1 $debug]
    printt_debug "Logic bound reversed: $logic_bound_rev" $debug
    set total_prev 0
    set fixed_slack $slack
    if {$can_borrow_prev(max_slack) != "" && $can_borrow_prev(max_slack) > 0} {
      set total_prev [expr $start_clk_latency_borrow + [lindex $logic_bound 0]]
      set total_prev [expr  {($total_prev>$can_borrow_prev(max_slack))?$can_borrow_prev(max_slack):$total_prev}]
      set fixed_slack [expr $fixed_slack + $total_prev]
    }
    set total_next 0
    if {$can_borrow_next(max_slack) != "" && $can_borrow_next(max_slack) > 0} {
      set total_next [expr $end_clk_latency_borrow + [lindex $logic_bound_rev 0]]
      set total_next [expr  {$total_next>$can_borrow_next(max_slack)?$can_borrow_next(max_slack):$total_next}]
      set fixed_slack [expr $fixed_slack + $total_next]
    }
    lappend ret [list $slack $can_borrow_prev(max_slack) $start_clk_latency_borrow [lindex $logic_bound 0] $total_prev $can_borrow_next(max_slack) $end_clk_latency_borrow [lindex $logic_bound_rev 0] $total_next [expr $total_prev + $total_next] $fixed_slack]
  }
  return $ret
}
proc sio_check_if_can_bound {port {debug 0}} {
  set max_latency 20
  set pins [get_pins $port -quiet]
  if {[sizeof_collection $pins] == 0} {
    printt "-E-:sio_check_if_can_bound: pin not found: $port"
    return 0
  }
  set partitions [get_partitions]
  set ret {{pin slack slack_prev latency_borrow_prev bound_to_logic_borrow_prev total_prev slack_next latency_borrow_next bound_to_logic_borrow_next total_next total fixed_slack}}
  foreach_in_collection pin $pins {
    set path [get_timing_path -through $pin -include_hierarchical_pins -max_paths 1 -slack_lesser_than 0]
    lappend ret [list [get_attribute $pin full_name] {*}[lindex [sio_check_if_can_bound_path $path $max_latency $debug] 0]]
  }

  printColumnarLines $ret
  return $ret
}

proc sio_check_if_can_bound_clk_latency {path {max_latency 20} {debug 0}} {
  printt_debug "Start: [arginfo]" $debug
  set target_latency [sio_mow_get_clk_target_get]
  set startpoint_clock_latency [get_attribute -quiet ${path} startpoint_clock_latency]
  set endpoint_clock_latency [get_attribute -quiet ${path} endpoint_clock_latency]
  set start -
  set end -
  if {$startpoint_clock_latency ne "" } {
    set start [expr {$max_latency - ($target_latency - $startpoint_clock_latency)}]
  }
  if {$endpoint_clock_latency ne "" } {
    set end [expr {$max_latency - ($endpoint_clock_latency - $target_latency)}]
  }
  if {$start <0} {
    set start 0
  }
  if {$end <0} {
    set end 0
  }
  return [list $start $end]
}

proc sio_check_if_can_bound_logic_nearest_logic {path partition {is_reversed 0} {debug 0}} {
  printt_debug "Start: [arginfo]" $debug
  set points [get_attribute -quiet $path points]
  set count [sizeof_collection $points]
  set i 0
  set delay 0
  set arrival 0
  while {$i < $count} {
    set idx [expr {$is_reversed ? $count -1 - $i : $i}]
    set point [index_collection $points $idx]
    set full_name [get_attribute -quiet $point object.full_name]
    set x [get_attribute -quiet $point object.x_coordinate]
    set y [get_attribute -quiet $point object.y_coordinate]
    set cell [get_attribute -quiet $point object.cell]
    set ref_name  [get_attribute -quiet $cell ref_name]
    printt_debug "Checking point: $full_name $ref_name" $debug
    if {![string equal -length [string length $partition] $partition $full_name]} {
      lassign [sio_mow_check_spec_get_realted_arrival_to_port $points $i] related_perc arrival_related pin_drv pin_rcv rcv_related
      return [list $delay $x $y $full_name $i]
    }
    incr i
    set is_hierarchical [get_attribute -quiet $cell is_hierarchical]
    if {$is_hierarchical} {
      set delay [expr abs([get_attribute -quiet $point arrival] - $arrival)]
      continue
    }

    set is_buff_inv [check_regexs_buffs_invs $ref_name]
    if {$is_buff_inv} {
      set delay [expr abs([get_attribute -quiet $point arrival] - $arrival)]
      continue
    }

    set is_sequential [get_attribute -quiet $cell is_sequential]
    if {$is_sequential} {
      if {[get_attribute -quiet $cell full_name] eq [expr {$is_reversed?[get_attribute -quiet $path endpoint.cell.full_name]:[get_attribute -quiet $path startpoint.cell.full_name]}]} {
        set arrival [get_attribute -quiet $point arrival]
        printt_debug "Found sequential cell at point: $full_name $arrival" $debug
        continue
      }
      return
    }
    set is_combinational [get_attribute -quiet $cell is_combinational]
    set is_black_box [get_attribute -quiet $cell is_black_box]
    return [list $delay $x $y $full_name $i]
  }
  return
}

proc sio_icg_check {icg} {
  set pins [get_pins -of_objects $icg -filter direction==out]
  set fanout [get_pins -of_objects [all_fanout -endpoints_only -flat -from $pins -quiet -only_cells] -filter direction==out]
  set min_slack [get_attribute [index_collection [sort_collection $fanout max_slack] 0] max_slack]
  return [list $min_slack [sizeof_collection $fanout]]
}

proc sio_mow_report_unbalance_spec {outfile} {
  # set partitions [get_partitions]
  set budget 168
  set partitions icore0/par_ooo_vec
  set pins [get_pins -of_objects $partitions -filter {is_hierarchical} -quiet]
  set out [open $outfile w]
  puts $out "pin,spec,abutted_port,abutted_spec,direction,diff,new_spec"
  set count 0
  foreach_in_collection pin $pins {
    if {[expr [incr count] % 1000] == 0} {
      printt "$count/[sizeof_collection $pins]"
    }
    set spec [sio_mow_get_pin_spec_any $pin]
    set name [get_attribute $pin full_name -q]
    set abutted_port [get_abutted_port $name]
    if {$abutted_port eq ""} {
      continue
    }
    set spec [sio_mow_get_pin_spec_any $pin]
    set abutted_spec [sio_mow_get_pin_spec_any [get_pins $abutted_port]]
    set diff -1
    catch {set diff [expr ($spec + $abutted_spec)-$budget]}
    set new_spec $spec
    if {$diff < 0 && $abutted_spec != ""&& $abutted_spec > 0} {
      set new_spec [expr $spec - $diff]
    }
    puts $out "\"[get_attribute $pin full_name]\",\"$abutted_port\",$spec,$abutted_spec,[get_attribute $pin direction],$diff,$new_spec"
  }
  close $out
}

proc sio_vec_rs_301h_find_X {outfile} {
  set pin_names {icore0/par_ooo_vec/rsvecfusedm301h_*_*_[*] icore0/par_ooo_vec/rsvecpdstm301h_*_[*] icore0/par_ooo_vec/rsvecdispfpcwm301h_*__*_*__op_2[*]}
  set out [open $outfile w]
  puts $out "pin,logic_x_coordinates"
  set pins [get_pins $pin_names -filter is_hierarchical -quiet]
  set count 0
  foreach_in_collection pin $pins {
    if {[get_attribute $pin direction] eq "in"} {
      set fanins [all_fanout -from $pin -flat -only_cells]
    } else {
      set fanins [all_fanin -to $pin -flat -only_cells]
    }
    set logics [filter_collection $fanins ref_name!~INV*&&ref_name!~BUF*&&is_hierarchical==false&&full_name!~*diode*]
    set logics [sort_collection $logics x_coordinate_max -descending]
    set port_x [get_attribute $pin x_coordinate]
    if {[catch {
      set diff [expr  $port_x - [get_attribute [index_collection $logics 0] x_coordinate_max]]
    } err]} {
      printt "-E-:sio_vec_rs_301h_find_X: cannot get coordinates for pin [index_collection $logics 0]: $err"
      printt "[sizeof_collection $logics] logics found for pin [get_attribute $pin full_name]"
      continue
    }
    if {[expr $diff > 50000]} {
      puts $out "[get_attribute $pin full_name],[expr [get_attribute [index_collection $logics 0] x_coordinate_max]/1000]"
    }
    incr count
  }
  close $out
  echo $count pins processed
}

proc sio_pceco_check_location {infile outfile} {
  set in [open $infile]
  set out [open $outfile w]
  puts $out "cell,distance,target_coords_x,target_coords_y,current_coords_x,current_coords_y,ref_name,pt_ref_name"
  gets $in header
  set i 0
  foreach c [split $header ,] {
    set c [string trim $c]
    set iheader($c) $i
    incr i
  }
  set count 0
  while {[gets $in line] >= 0} {
    incr count
    if {[expr $count % 1000000] == 0} {
      printt "$count lines processed"
      # break
    }
    set fields [split $line ,]
    lassign [lindex $fields $iheader(global_coordinate) 0 0] x y
    set ref_name [lindex $fields $iheader(ref_name)]
    set c [lindex $fields $iheader(full_name)]
    if {[lindex [split $c /] 0] eq "icore1"} {
      continue
    }
    set cell [get_cells ${c}]

    set is_hierarchical [get_attribute $cell is_hierarchical]
    if {$is_hierarchical eq "true"} {
      continue
    }
    if {[catch {
      set x_curr [expr [get_attribute $cell x_coordinate_min]/1000]
      set y_curr [expr [get_attribute $cell y_coordinate_min]/1000]
      set pt_ref_name [get_attribute $cell ref_name]
      # calculate distance
      set dist [expr abs($x_curr - $x) + abs($y_curr - $y)]
      if {[expr $dist > 5] || $ref_name ne $pt_ref_name} {
        puts $out "$c,$dist,$x,$y,$x_curr,$y_curr,$ref_name,$pt_ref_name"
      }
    } err]} {
      printt "-E-:sio_pceco_check_location: cannot get coordinates for cell ${c}: '$err'"
      printt "$count: '$x' '$y' '$x_curr' '$y_curr' '$ref_name' '$pt_ref_name' $is_hierarchical"
    }
  }
  close $in
  close $out
}

proc sio_vec_exe_find_ports_logic_only_not_in_middle {outfile} {
  set ports [get_pins icore0/par_ooo_vec/*]

  set debug 0
  if {$debug} {
    set ports [get_pins icore0/par_ooo_vec/rsvecavoidm301h_op_2[1]]
  }

  set n "icore0/par_exe/"
  array set done {}
  set out [open $outfile w]
  puts $out "pin,direction,abutted_pin,all_logic_not_in_middle,slack,x_pin,y_pin,fanins_count,fanouts_count,fanins_x_min,fanins_x_max,fanouts_x_min,fanouts_x_max"
  foreach_in_collection port $ports {
    set abutted [get_abutted_port [get_attribute $port full_name]]
    set direction [get_attribute $port direction]
    if {![string equal -length [string length $n] $abutted $n]} {
      continue
    }
    set pins_to_check [filter_collection [all_fanin -to $port -flat] full_name=~${n}*&&!cell.is_sequential&&!is_hierarchical]
    append_to_collection pins_to_check [filter_collection [all_fanout -from $port -flat] full_name=~${n}*&&!cell.is_sequential&&!is_hierarchical]
    if {$debug} {
      printt "****[join [get_attribute $pins_to_check full_name] \n]****"
    }
    set all_done 1
    foreach_in_collection pin $pins_to_check {
      set pin_name [get_attribute $pin full_name]
      if {![info exists done($pin_name)]} {
        set done($pin_name) [sio_vec_exe_find_ports_logic_only_not_in_middle_check $pin]
      }
      if {$debug} {
        printt "$pin_name $done($pin_name)"
      }
      if {$done($pin_name) == 0} {
        set all_done 0
        break
      }
    }
    set all_fanouts [sort_collection [all_fanout -from $port -flat -endpoints_only] x_coordinate]
    set all_fanins [sort_collection [all_fanin -to $port -flat -startpoints_only] x_coordinate]
    set slack NA
    if {$all_done} {
      set slack [get_attribute [get_timing_path -through $port] slack]
    }
    if {[catch {puts $out "[get_attribute $port full_name],$direction,$abutted,$all_done,$slack,\
      [expr [get_attribute $port x_coordinate]/1000],\
        [expr [get_attribute $port y_coordinate]/1000],\
        [sizeof_collection $all_fanins],\
        [sizeof_collection $all_fanouts],\
        [expr [get_attribute [index_collection $all_fanins 0] x_coordinate]/1000],\
        [expr [get_attribute [index_collection $all_fanins end] x_coordinate]/1000],\
        [expr [get_attribute [index_collection $all_fanouts 0] x_coordinate]/1000],\
        [expr [get_attribute [index_collection $all_fanouts end] x_coordinate]/1000]"
    } err]} {
    printt "-E-:sio_vec_exe_find_ports_logic_only_not_in_middle: cannot write output for pin [get_attribute $port full_name]: $err"
    continue
  }
}
close $out
}
# check if there no start/end points in the middle area of exe partition
proc sio_vec_exe_find_ports_logic_only_not_in_middle_check {pin} {
  set n "icore0/par_exe/"
  set pins_to_check [filter_collection [all_fanin -to $pin -flat -only_cells -startpoints_only] full_name=~${n}*]
  append_to_collection pins_to_check [filter_collection [all_fanout -from $pin -flat -only_cells -endpoints_only] full_name=~${n}*]
  set cells [filter_collection $pins_to_check y_coordinate_min<830000&&x_coordinate_min>300000&&x_coordinate_max<400000]
  # puts "[join [get_attribute $pin full_name] \n]"
  return [expr [sizeof_collection $cells]==0]
}

proc run_sio_vec_sio_logic_count_path_data_parallel {pins} {

}

proc vec_TD_unconst_ports {outfile} {
  set pins [get_pins icore0/par_ooo_vec/* -filter max_slack=="INFINITY"]
  set out [open $outfile w]
  puts $out "pin,fanin,fanout"
  foreach_in_collection pin $pins {
    set eps [filter_collection [all_fanin -to $pin -flat -startpoints_only] is_hierarchical==false]
    set sps [filter_collection [all_fanout -from $pin -flat -endpoints_only] is_hierarchical==false]
    foreach p $eps {
      puts $out "\"[get_attribute $pin full_name]\",\"[join [get_attribute $p full_name] { } ]\","
    }
    foreach e $sps {
      puts $out "\"[get_attribute $pin full_name]\",,[join [get_attribute $e full_name] { } ]"
    }
    if {[sizeof_collection $eps] == 0 && [sizeof_collection $sps] == 0} {
      puts $out "\"[get_attribute $pin full_name]\",,"
    }
  }
  close $out
}

proc sio_check_if_external_is_internal {_pin} {
  # TSMC ONLY
  array set ret {}
  set pars [get_partitions]
  set pins [get_pins $_pin]
  foreach_in_collection pin $pins {
    set direction [get_attribute $pin direction]
    set pin_name [get_attribute $pin full_name]
    set partition [get_partition_from_name $pin_name $pars]
    set clk [string map {par mclk} [lindex [split $partition /] end]]
    if {$direction eq "out"} {
      set fanins [get_pins -of_objects [all_fanin -to $pin -flat -only_cells -startpoints_only] -filter lib_pin_name=~Q*]
      foreach_in_collection fain $fanins {
        set tp [get_timing_path -through $fain -include_hierarchical_pins -to $clk]
        set key "$pin_name,$direction,[get_attribute $tp endpoint.cell.full_name]"
        if {[sizeof_collection $tp] > 0} {
          set ret($key) 1
        }
      }
    } else {
      set fanouts [get_pins -of_objects [all_fanout -from $pin -flat -only_cells -endpoints_only] -filter lib_pin_name=~D*]
      foreach_in_collection faout $fanouts {
        set tp [get_timing_path -through $faout -include_hierarchical_pins -from $clk]
        set key "$pin_name,$direction,[get_attribute $tp endpoint.cell.full_name]"
        if {[sizeof_collection $tp] > 0} {
          set ret($key) 1
        }
      }
    }
  }
  foreach k [lsort [array names ret]] {
    puts "$k"
  }
  return
}

proc sio_check_ROWbEnM804H {outfile} {
  set out [open $outfile w]
  set icgs [get_cells rob/rob_clk/core_icg_ROClkWbMH_0_/*gate_te_ctech_lib_clk_gate_te_dcszo*]
  puts $out "icg,x_icg,y_icg,compress_ff,ff,x_ff,y_ff"
  foreach_in_collection icg $icgs {
    set pins_of_icg [get_pins -of_objects $icg -filter lib_pin_name=~Q]
    foreach_in_collection pin $pins_of_icg {
      set ffs [all_fanout -from $pin -flat -only_cells -endpoints_only]
      foreach_in_collection ff $ffs {
        set compress_pin [compress_pin_name [get_attribute $ff full_name]]
        puts $out "[get_object_name $icg],[expr [get_attribute $icg x_coordinate_min]/1000],[expr [get_attribute $icg y_coordinate_min]/1000],$compress_pin,[get_object_name $ff],[expr [get_attribute $ff x_coordinate_min]/1000],[expr [get_attribute $ff y_coordinate_min]/1000]"
      }
    }
  }
  close $out
}
