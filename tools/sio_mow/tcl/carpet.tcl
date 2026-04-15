namespace eval Carpet {
  namespace eval draw {
    variable  max_count 10000
    variable null null
    proc get_x_y {obj} {
      if {[get_attribute $obj object_class] eq "cell" || [get_attribute $obj object_class] eq "net"} {
        return [get_x_y_cell $obj]
      }
      return [get_x_y_pin $obj]
    }
    proc get_x_y_cell {obj} {
      variable null
      set x_min [get_attribute $obj x_coordinate_min -quiet]
      set y_min [get_attribute $obj y_coordinate_min -quiet]
      set x_max [get_attribute $obj x_coordinate_max -quiet]
      set y_max [get_attribute $obj y_coordinate_max -quiet]
      if {$x_min ne "" && $y_min ne "" && $x_max ne "" && $y_max ne ""} {
        set x [expr {($x_min + $x_max) / 2}]
        set y [expr {($y_min + $y_max) / 2}]
      } else {
        set x ""
        set y ""
      }
      if {$x == ""} {
        set x_um $null
      } else {
        set x_um [expr {$x / 1000}]
      }
      if {$y == ""} {
        set y_um $null
      } else {
        set y_um [expr {$y / 1000}]
      }
      return [list $x_um $y_um]
    }
    proc get_x_y_pin {obj} {
      variable null
      set x [get_attribute $obj x_coordinate -quiet]
      set y [get_attribute $obj y_coordinate -quiet]
      if {$x == ""} {
        set x_um $null
      } else {
        set x_um [expr {$x / 1000}]
      }
      if {$y == ""} {
        set y_um $null
      } else {
        set y_um [expr {$y / 1000}]
      }
      return [list $x_um $y_um]
    }

    proc from_to_get_object {input object_class} {
      set ret ""
      if {$object_class eq "pin"} {
        set ret [get_pins $input]
      }
      if {$object_class eq "cell"} {
        set ret [get_cell $input]
      }
      if {$object_class eq "port"} {
        set ret [get_ports $input]
      }
      if {$object_class eq "net"} {
        set ret [get_nets $input]
      }
      return $ret
    }
    proc from_to {data} {
      variable max_count

      set ret [list]
      if {[llength $data] > $max_count} {
        set data [lrange $data 0 $max_count]
        puts "Warning: count is too high: [llength $data], use only first $max_count"
      }
      foreach {from to} $data {
        lassign $from from_name from_object_class
        lassign $to to_name to_object_class
        set from_obj [from_to_get_object $from_name $from_object_class]
        set to_obj [from_to_get_object $to_name $to_object_class]
        lassign [get_x_y $from_obj] from_x from_y
        lassign [get_x_y $to_obj] to_x to_y
        lappend ret \{"to":\{[make_json_fan $to_name $to_object_class $to_x $to_y]\},"from":\{[make_json_fan $from_name $from_object_class $from_x $from_y]\}\}
      }
      return "\{\"data\":\[[join $ret ,]\]\,\"type\":\"from_to\"\}"

    }
    proc make_json_fan {name object_class x y} {
      set json "\"name\":\"$name\",\"object_class\":\"$object_class\",\"x\":$x,\"y\":$y"
      return $json
    }
    proc sio_draw_fanin {input type args} {
      set from {}
      if {$type eq "pins"} {
        set from [get_pins $input]
      }
      if {$type eq "cells"} {
        set from [get_cell $input]
      }
      if {$type eq "ports"} {
        set from [get_ports $input]
      }
      if {$type eq "nets"} {
        set from [get_nets $input]
      }
      set count 0
      set data [list]
      foreach_in_collection field $from {
        set object_class [get_attribute $field object_class]
        set name [get_attribute $field full_name]
        set fanins [all_fanin -to $field {*}$args -quiet]
        foreach_in_collection fanin $fanins {
          set fanin_object_class [get_attribute $fanin object_class]
          set fanin_name [get_attribute $fanin full_name]
          if {$fanin_name ne $name} {
            lappend data [list $fanin_name $fanin_object_class] [list $name $object_class]
          }
        }
      }
      return [from_to $data]
    }
    proc sio_draw_fanout {input type args} {
      set from {}
      if {$type eq "pins"} {
        set from [get_pins $input]
      }
      if {$type eq "cells"} {
        set from [get_cell $input]
      }
      if {$type eq "ports"} {
        set from [get_ports $input]
      }
      if {$type eq "nets"} {
        set from [get_nets $input]
      }
      set count 0
      set data [list]
      foreach_in_collection field $from {
        set object_class [get_attribute $field object_class]
        set name [get_attribute $field full_name]
        set fanouts [all_fanout -from $field {*}$args -quiet]
        foreach_in_collection fanout $fanouts {
          set fanout_object_class [get_attribute $fanout object_class]
          set fanout_name [get_attribute $fanout full_name]
          if {$name ne $fanout_name} {
            lappend data [list $name $object_class] [list $fanout_name $fanout_object_class]
          }
        }
      }
      return [from_to $data]
    }
    proc sio_draw_points {input type args} {
      variable max_count
      set data ""
      if {$type eq "pins"} {
        set data [get_pins $input {*}$args]
      }
      if {$type eq "cells"} {
        set data [get_cells $input {*}$args]
      }
      if {$type eq "ports"} {
        set data [get_ports $input {*}$args]
      }
      if {$type eq "nets"} {
        set data [get_nets $input {*}$args]
      }
      
      if {[set count [sizeof_collection $data]]> $max_count} {
        set data [index_collection $data 0 $max_count]
        puts "Warning: count for $input is too high: $count, use only first $max_count"
      }
      set ret [list]
      foreach_in_collection field $data {
        set object_class [get_attribute $field object_class]
        set name [get_attribute $field full_name]
        lassign [get_x_y $field] x y
        lappend ret "\{[make_json_fan $name $object_class $x $y]\}"
      }
      return "\{\"data\":\[[join $ret ,]\]\,\"type\":\"points\"\}"
    }
    proc get_allowed_commands {} {
      return [list "sio_draw_points" "sio_draw_fanin" "sio_draw_fanout"]
    }
  }
}
