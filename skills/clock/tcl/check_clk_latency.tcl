proc check_clk_latency { clock } {
     
        # ugly hard-coding michel
        set nworst 500000

        if { $::synopsys_program_name eq "pt_shell" } {

                redirect -var result_launch {report_clock_timing -type latency -clock $clock -nworst $nworst -nosplit -launch}
                redirect -var result_capture {report_clock_timing -type latency -clock $clock -nworst $nworst -nosplit -capture}
        } 

	set ntwrk_latency_index "end-2"
	set src_latency_index "end-3"

        set ntwrk_latencies [list]
        set src_latencies [list]

        set result ""
        append result "$result_launch "
        append result "$result_capture "
        set ln_rpt [split $result "\n"]
        if { $ln_rpt eq "" } { return }
        foreach line $ln_rpt {
            if { [regexp {\-----} $line] } { continue }
            if { [regexp {checkpin_falling} $line] } { continue }
            set ntwrk_latency [lindex $line $ntwrk_latency_index]
            set src_latency [lindex $line $src_latency_index]

            if { $ntwrk_latency=="" || ! [regexp {[0-9]+\.[0-9]+} $ntwrk_latency] } {
                #puts "-D-line: $line -- latency: $latency"
                continue
            }
            if { $ntwrk_latency<=0 } { continue }
            lappend ntwrk_latencies $ntwrk_latency

	    if { $src_latency< 0 } { continue }
            lappend src_latencies $src_latency
        }

        set ntwrk_vector $ntwrk_latencies
        set ntwrk_length [llength $ntwrk_vector]
        set ntwrk_sum   [expr [join $ntwrk_vector +]]
        set ntwrk_avg   [format %.0f [expr {$ntwrk_sum/1.0/$ntwrk_length}]]

	set src_vector $src_latencies
        set src_length [llength $src_vector]
        set src_sum   [expr [join $src_vector +]]
        set src_avg   [format %.0f [expr {$src_sum/1.0/$src_length}]]

	#puts "$avg"
        
    puts "$clock,$ntwrk_avg,$src_avg"
}
