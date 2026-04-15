proc bi_strip_mbit { pin } {
        set pin_name  $pin 
        set pin_array [split $pin_name "/" ] 
        set mbit_port [lindex $pin_array end ] 
        set mbit_index [regsub -all {[A-z]} ${mbit_port} "" ]
        set mbit_signal  [lindex $pin_array end-1 ] 
        if [regexp {MBIT} $mbit_signal ] {
            if {$mbit_index!=""} { 
                #if we know the bit order ....
                set mbit_signal_array [regsub -all {_MBIT_} $mbit_signal "\n" ] 
                set new_name [lrange $pin_array 0 end-2]
                append new_name "/[lindex $mbit_signal_array $mbit_index ]"
                append new_name "/[regsub -all {[0-9]} ${mbit_port} {} ]"
                puts -nonewline "[regsub -all { } $new_name {/} ]"
            } else {
                #in case it is clock then compress the pin_name
                set mbit_signal_array [regsub -all {_MBIT_} $mbit_signal "\n" ] 
                set compressed_mbit [lindex $mbit_signal_array 0 ]
                set new_name [lrange $pin_array 0 end-2]
                append new_name "/[regsub -all {\n} $compressed_mbit {*} ]"
                append new_name "/[regsub -all {[0-9]} ${mbit_port}* {} ]"
                puts -nonewline "[regsub -all { } $new_name {/} ]"
            }
        } else {
            puts -nonewline "$pin_name"
        }
    
}

proc bi_strip_mbit_from_report { report } {
    foreach line [split $report "\n" ] {
        foreach word [regexp -inline -all -- {\S+|\s+} $line] {
            if [regexp {MBIT} $word ] {
                puts -nonewline "[bi_strip_mbit $word] "
            } else {
                puts -nonewline "$word" 
            }
        }
        puts ""
    }
}

bi_strip_mbit_from_report [exec cat [lindex $argv 0]]