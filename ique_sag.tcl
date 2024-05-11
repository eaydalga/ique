#

namespace eval sag {
    # array of frames/windows containing frame attributes
    # attributes include selected list and buddy list
    variable windows
    variable buddydata
   
    # The public interface
    namespace export \
            init \
            remove \
            remove_all \
            change_icon \
            change_mainstring \
            change_othersting \
            pos_2_mainstring \
            pos_2_index \
            nearest \
            insert \
            add \
            destroy \
            selection
}

# sag::init --
#     Initialize a sag window
#
# Arguments:
#     winName   - frame name
#     width     - initial width
#     height    - initial height
#     scrollbar - have a right side scrollbar?
#     font      - font used for all text
#     highlight - color used for selections

proc sag::init { winName {width 300} {height 400} { scrollbar "no" } \
                 { font {} } {highlight {#a9a9a9} } } {
 
    frame $winName

    canvas $winName.c -relief sunken \
            -width $width \
            -borderwidth 2 \
            -height $height

    # Create the optional scrollbar
    if { [string compare $scrollbar "yes"] == 0 } {
        scrollbar $winName.sb -command [list \
                        sag::yview_set $winName.c] 
        pack $winName.sb -side right \
                -fill y

        $winName.c configure \
                -yscrollcommand [list $winName.sb set] \
                -scrollregion [list 0 0 $width $height]
    }

    pack $winName.c -side left \
            -fill both \
            -expand true

    #
    # Now, bind some events
    #
    bind $winName.c <B1-Motion> \
            [list sag::dragSelect $winName %x %y move 0 ]

    bind $winName.c <ButtonRelease-1> \
            [list sag::dragSelect $winName %x %y stop 0 ]

    bind $winName.c <Button-1> \
            [list sag::dragSelect $winName %x %y start 1 ]


    bind $winName.c <Control-Button-1> \
            [list sag::dragSelect $winName %x %y start 0 ]

    bind $winName.c <Double-Button-1> {}

    bind $winName.c <Configure> +[list sag::resize $winName]

    # Contains a list of indexes corresponding to
    # the current selection
    set sag::windows($winName,selected) [list]

    set sag::windows($winName,highlight) $highlight


    #
    # Display list is just a map from index to canvas
    # object ids.  The object id for a displayed mainstring
    # will be the key object id for use in the buddydata
    # array.
    #
    set sag::windows($winName,displaylist) [list]

    set sag::windows($winName,font) $font
    set sag::windows($winName,maxMainWidth) 0
    set sag::windows($winName,lineheight) \
            [font metrics $sag::windows($winName,font) -linespace]
    set sag::windows($winName,longest) 0

    return $winName.c
}

# sag::resize --
#     Handle changing the highlight area.
#
# Arguments:
#     winName - SAG component
proc sag::resize {winName} {
    set lineheight $sag::windows($winName,lineheight)
    set width [winfo width $winName.c]

    foreach hbox [$winName.c find withtag highlight] {
        foreach {x y wx hy} [$winName.c coords $hbox] {}

        $winName.c delete $hbox
        $winName.c create rectangle \
            $x $y [expr $width - 7] $hy \
            -fill $sag::windows($winName,highlight) \
            -outline $sag::windows($winName,highlight) \
            -tag highlight
    }


    $winName.c lower highlight

    sag::reset_scrollregion $winName
}


# sag::selection --
#     Just return the list of indices that
#     have been selected.
#
# Arguments:
#     winName - SAG component

proc sag::selection { winName } {
    
    set result [list]
    foreach idx $sag::windows($winName,selected) {
        set index [lindex $sag::windows($winName,displaylist) $idx]
        lappend result $sag::buddydata($winName,$index,mainstr)
    }
    
    return $result
}


# sag::insert --
#     Tag all the iconname mainstr and otherstr canvas objects
#     with the same id so we can get to them easily
#
# Arguments:
#     winName - SAG component
#     pos        - where to place the item
#     indent     - distance to indent the everything
#     iconname   - icon to display
#     mainstr    - string display after the icon, such as buddy name
#     otherstr   - string display on the very right, such as idle time
#     maincolor  - color of the main string
#     othercolor - color of the other string
#
# Results:
#     The index of the item inserted.

proc sag::insert { winName pos indent iconname \
                   mainstr otherstr \
                   maincolor othercolor} {

    # Determine the exact index
    set index $pos
    if { $pos < 0 } {
        set index 0
    }
    if { ($pos >= [llength $sag::windows($winName,displaylist)]) \
            || ($pos == "end") } {
        set index [llength $sag::windows($winName,displaylist)]
    }

    # This won't do anything if index >= the number 
    # of buddies.
    sag::shift_buddies $winName $index down

    set lineheight $sag::windows($winName,lineheight)
    set y [expr ($lineheight * $index) ]
    set mainOffset 16

    # font measure is very slow on unix machines, skip by only
    # mesuring strings >= the longest string so far.
    if { [string length $mainstr] >= $sag::windows($winName,longest) } {
        set len [font measure $sag::windows($winName,font)\
            "$mainstr "]
        set sag::windows($winName,longest) [string length $mainstr]

        if { $len > $sag::windows($winName,maxMainWidth) } {
            $winName.c move otherTag \
                [expr $len - $sag::windows($winName,maxMainWidth)] 0
            set sag::windows($winName,maxMainWidth) $len
        }
    }

    set otherOffset $sag::windows($winName,maxMainWidth)
    incr otherOffset $mainOffset
    
    set icon ""
    catch {set icon [$winName.c create image $indent $y \
            -image $iconname \
            -anchor nw]}
    set main [$winName.c create text [expr $indent + $mainOffset] $y \
            -text $mainstr \
            -fill $maincolor \
            -font $sag::windows($winName,font) \
            -anchor nw]
    set other [$winName.c create text [expr $indent + $otherOffset] $y \
            -text $otherstr \
            -fill $othercolor \
            -font $sag::windows($winName,font) \
            -anchor nw\
            -tags otherTag]

    set sag::buddydata($winName,$main,iconname) $iconname
    set sag::buddydata($winName,$main,icon) $icon
    set sag::buddydata($winName,$main,mainstr) $mainstr
    set sag::buddydata($winName,$main,main) $main
    set sag::buddydata($winName,$main,otherstr) $otherstr
    set sag::buddydata($winName,$main,other) $other

    set sag::windows($winName,displaylist) [linsert \
            $sag::windows($winName,displaylist) $pos \
            $main ]

    #
    # Reset the canvas scroll region
    #
    sag::reset_scrollregion $winName

    return $main
}

# sag::add --
#     Same as sag::insert, with pos set to "end"

proc sag::add { winName indent iconname mainstr otherstr maincolor othercolor} {
    return [ sag::insert $winName end $indent $iconname \
            $mainstr $otherstr \
            $maincolor $othercolor ]
}

# sag::change_icon --
#     Change the icon for a item in the list
#
# Arguments:
#     winName     - the SAG component
#     index       - the index to change
#     newiconname - new icon to use

proc sag::change_icon { winName index newiconname } {
    set icon $sag::buddydata($winName,$index,icon)
    set sag::buddydata($winName,$index,iconname) $newiconname
    $winName.c itemconfigure $icon -image $newiconname
}


# sag::change_mainstring --
#     Change the mainstr for a item in the list
#
# Arguments:
#     winName   - the SAG component
#     index     - the index to change
#     newstring - new main string to use

proc sag::change_mainstring { winName index newstring } {
    set main $sag::buddydata($winName,$index,main)
    set sag::buddydata($winName,$index,mainstr) $newstring
    $winName.c itemconfigure $main -text $newstring

    # Check to see if this changes the spacing between
    # otherstr and mainstr
    set width [font measure $sag::windows($winName,font) \
            "$newstring "]
    if { $width > $sag::windows($winName,maxMainWidth) } {
        $winName.c move otherTag \
                [expr $width - $sag::windows($winName,maxMainWidth)] 0
        set sag::windows($winName,maxMainWidth) $width
    }
}

# sag::change_otherstring --
#     Change the otherstr for a item in the list
#
# Arguments:
#     winName     - the SAG component
#     index       - the index to change
#     newiconname - new icon to use

proc sag::change_otherstring { winName index newstring } {
    set other $sag::buddydata($winName,$index,other)
    set sag::buddydata($winName,$index,otherstr) $newstring
    $winName.c itemconfigure $other -text $newstring
}

# sag::pos_2_mainstring --
#     Given the Y position return the mainstring
#
# Arguments:
#     winName - the SAG component
#     pos     - the Y position we are interested in.
proc sag::pos_2_mainstring { winName pos} {
    if { ($pos < 0) || ($pos >= [llength $sag::windows($winName,displaylist)] ) } {
        return ""
    }

    set obj [lindex $sag::windows($winName,displaylist) $pos]
    return $sag::buddydata($winName,$obj,mainstr)
}

# sag::pos_2_index --
#     Given the Y position return the index
#
# Arguments:
#     winName - the SAG component
#     pos     - the Y position we are interested in.

proc sag::pos_2_index { winName pos} {
    if { ($pos < 0) || ($pos >= [llength $sag::windows($winName,displaylist)] ) } {
        return end
    }

    return [lindex $sag::windows($winName,displaylist) $pos]
}

# sag::nearest --
#     Return the position of the nearest element to a mouse click.
#
# Arguments:
#     winName - the SAG component
#     y       - the y mouse click (%y)
proc sag::nearest { winName y } {
    set cy [$winName.c canvasy $y]
    return [expr int( $cy / $sag::windows($winName,lineheight))]
}


# sag::remove --
#     Remove a item from the list
#
# Arguments:
#     winName - the SAG component
#     index   - index of element to remove

proc sag::remove { winName index } {

    # This helps clean things up a bit
    sag::clearSelection $winName

    if { ! [info exists sag::buddydata($winName,$index,main)] } {
        return
    }

    # Remove the objects from the canvas
    $winName.c delete $sag::buddydata($winName,$index,icon)
    $winName.c delete $sag::buddydata($winName,$index,main)
    $winName.c delete $sag::buddydata($winName,$index,other)

    # Remove the entry from the display list
    set where [lsearch -exact $sag::windows($winName,displaylist) \
            $sag::buddydata($winName,$index,main)]
    set sag::windows($winName,displaylist) [lreplace \
            $sag::windows($winName,displaylist) $where $where]

    # Unset elements in array
    foreach i [array names sag::buddydata $winName,$index,*] {
        unset sag::buddydata($i)
    }


    # Adjust vertical spacing
    sag::shift_buddies $winName $where up

    #
    # Now find the max mainstring and respace the
    # other strings.
    #
    set length [llength $sag::windows($winName,displaylist)]
    set max 0
    set longest 0

    for { set i 0 } { $i < $length } { incr i } {
        set obj [lindex $sag::windows($winName,displaylist) $i]
        set mainstr $sag::buddydata($winName,$obj,mainstr)

        # font measure slow on unix, skip if possible.
        if {[string length $mainstr] >= $longest} {
            set width [font measure $sag::windows($winName,font) \
                    "$mainstr "]
            if { $width > $max } {
                set max $width
            }
            set longest [string length $mainstr]
        }
    }
    set sag::windows($winName,longest) $longest
    set diff [expr $max - $sag::windows($winName,maxMainWidth)]
    set sag::windows($winName,maxMainWidth) $max
    $winName.c move otherTag $diff 0

    sag::reset_scrollregion $winName
}

# sag::remove_all --
#     Remove all the elements from the list
#
# Arguments:
#     winName - the SAG component

proc sag::remove_all { winName } {

    foreach elem [array names sag::buddydata $winName,*] {
        unset sag::buddydata($elem)
    }
    
    $winName.c delete all

    unset sag::windows($winName,displaylist)
    set sag::windows($winName,displaylist) [list]
    set sag::windows($winName,maxMainWidth) 0
    set sag::windows($winName,longest) 0
}


# sag:: destroy --
#     Delete a SAG widget and its associated data.
#
# Arguments:
#     winName - the SAG component
proc sag::destroy { winName } {
    destroy $winName

    foreach elem [array names sag::buddydata $winName,*] {
        unset sag::buddydata($elem)
    }

    unset sag::windows($winName,displaylist) 
    unset sag::windows($winName,font)
    unset sag::windows($winName,maxMainWidth)
    unset sag::windows($winName,lineheight)
}

#********* CALLBACKS & UTILITY ROUTINES ***********

# sag::shift_buddies --
#

proc sag::shift_buddies { winName index direction } {

    set lineheight $sag::windows($winName,lineheight)
    set yOffset 0
    if { [string compare $direction "up"] == 0 } {
        set yOffset -$lineheight
    }
    if { [string compare $direction "down"] == 0 } {
        set yOffset $lineheight
    }

    if { $yOffset == 0 } {
        return
    }

    set length [llength $sag::windows($winName,displaylist)]
    for {set i $index} { $i < $length } {incr i} {
        set obj [lindex $sag::windows($winName,displaylist) $i]
        $winName.c move $sag::buddydata($winName,$obj,icon) 0 $yOffset
        $winName.c move $sag::buddydata($winName,$obj,main) 0 $yOffset
        $winName.c move $sag::buddydata($winName,$obj,other) 0 $yOffset
    }
}

# sag::addToSelection --
#
proc sag::addToSelection { winName x y } {

    set x [$winName.c canvasx $x]
    set y [$winName.c canvasy $y]

    # sanity check
    if { ($x < 0) || ($y < 0) } {
        return
    }

    set lineheight $sag::windows($winName,lineheight)
    set idx [expr int($y / $lineheight)]

    set where [lsearch -exact \
            $sag::windows($winName,selected) \
            $idx]
    if { $where != -1 } { # preserve uniqueness
        #If it is in there, remove it
        set sag::windows($winName,selected) \
                [lreplace $sag::windows($winName,selected) \
                $where $where]

        # Find the object that corresponds to the rectangle
        # and delete it.
        set objid [lindex $sag::windows($winName,displaylist) $idx]
        set obj $sag::buddydata($winName,$objid,main)
        foreach {x1 y1 x2 y2} [$winName.c bbox $obj] {}

        set mid [expr int(($y1 + $y2) / 2)]
        set possible [$winName.c find overlapping \
                0 [expr $mid - 1] 15 [expr $mid + 1]]
        foreach obj $possible {
            if { [string compare rectangle \
                    [$winName.c type $obj]] == 0 } {
                $winName.c delete $obj
                break
            }
        }
        
        return
    }

    lappend sag::windows($winName,selected) $idx
    sag::hilight $winName $idx $idx highlight
}

# sag::highlight --
#
proc sag::hilight { winName first last tag } {

    #setup the first point
    set idx [lindex $sag::windows($winName,displaylist) $first]
    set obj $sag::buddydata($winName,$idx,main)
    foreach {x1 y1 x2 y2} [$winName.c bbox $obj] {}
    set mid1 [expr int( ($y1 + $y2) / 2 )]

    #setup the second point if different from first
    if { $first != $last } {
        set idx [lindex $sag::windows($winName,displaylist) $last]
        set obj $sag::buddydata($winName,$idx,main)
        foreach {x1 y1 x2 y2} [$winName.c bbox $obj] {}
        set mid2 [expr int( ($y1 + $y2) / 2 )]
    } else {
        set mid2 $mid1
    }


    set lineheight $sag::windows($winName,lineheight)
    set off [expr int( $lineheight / 2 )]
    set right [expr [winfo width $winName.c] - 7]

    if { [string compare $tag {rangehighlight}] == 0 } {
        $winName.c create rectangle \
                0 [expr $mid1 - $off] $right [expr $mid2 + $off] \
                -fill $sag::windows($winName,highlight) \
                -outline black \
                -tag $tag

    } else {
        $winName.c create rectangle \
                0 [expr $mid1 - $off] $right [expr $mid2 + $off] \
                -fill $sag::windows($winName,highlight) \
                -outline $sag::windows($winName,highlight) \
                -tag $tag

    }

    $winName.c lower rangehighlight
    $winName.c lower highlight
}

# sag::unhilight --
# 
proc sag::unhilight { winName index tag } {

    #setup the first point
    set idx [lindex $sag::windows($winName,displaylist) $index]
    set obj $sag::buddydata($winName,$idx,main)
    foreach {x1 y1 x2 y2} [$winName.c bbox $obj] {}
    set mid [expr int( ($y1 + $y2) / 2 )]

    set lineheight $sag::windows($winName,lineheight)
    set off [expr int( $lineheight / 2 )]
    set right [expr [winfo width $winName.c] - 7]

    set possible [$winName.c find overlapping \
            0 [expr $mid - 1] 10 [expr $mid + 1]]
    foreach p $possible {
        if { [string compare rectangle \
                [$winName.c type $p]] == 0 } {
            $winName.c delete $p
        }           
    }
}

# sag::clearSelection --
#     Unselect all items.
proc sag::clearSelection { winName } {
    $winName.c delete highlight
    $winName.c delete rangehighlight
    unset sag::windows($winName,selected)
    set sag::windows($winName,selected) [list]
    if { [info exists sag::windows($winName,anchor)] } {
        unset sag::windows($winName,anchor)
    }    
    if { [info exists sag::windows($winName,end)] } {
        unset sag::windows($winName,end)
    }
}

# sag::dragSelect --
#     Callback for most button motions, handle the user
#     dragging and selecting items.
proc sag::dragSelect { winName x y event clear } {

    if { [string compare $event stop] == 0 } {
        if { ![info exists sag::windows($winName,anchor)] } {
            return
        }

        set a $sag::windows($winName,anchor)
        set first $a
        set e $sag::windows($winName,end)

        if {( $e < $a )} {
            set tmp $e
            set e $a
            set a $tmp
        }

        $winName.c delete rangehighlight

        set idx [lsearch -exact $sag::windows($winName,selected) $first]
        if { $idx < 0 } {
            # we are adding to the selection
            for { set i $a } { $i <= $e } { incr i } {
                if { [lsearch -exact $sag::windows($winName,selected) $i] < 0 } {
                    lappend sag::windows($winName,selected) $i
                    sag::hilight $winName $i $i highlight
                }
            }
        } else {
            # we are removing elements from the selection
            set newlist $sag::windows($winName,selected)
            for { set i $a } { $i <= $e } { incr i } {
                set pos [lsearch -exact $newlist $i]
                if { $pos >= 0 } {
                    set newlist \
                            [lreplace $newlist $pos $pos]
                    sag::unhilight $winName $i highlight
                }
            }

            set sag::windows($winName,selected) $newlist
        }


        unset sag::windows($winName,anchor)
        unset sag::windows($winName,end)

        return
    }

    # Convert to canvas coords and check
    # for valid bounds.
    set cx [$winName.c canvasx $x]
    set cy [$winName.c canvasy $y] 
    set cheight [expr [lindex [$winName.c cget -scrollreg] 3] \
            - [lindex [$winName.c cget -scrollreg] 1] ]

    if { ($cy < 0) || ($cy >= $cheight) } {
        return
    }


    set lineheight $sag::windows($winName,lineheight)
    set index [expr int($cy / $lineheight)]

    if { [string compare $event start] == 0 } {
        if { $clear } {
            sag::clearSelection $winName
        }

        set sag::windows($winName,anchor) $index
        set sag::windows($winName,end) $index

        set index1 $index
        set index2 $index

    }

    if { [string compare $event move] == 0 } {
        # Do the auto scroll
        set bottom [expr [winfo y $winName] + [winfo height $winName]]
        set top [winfo y $winName]
        if { $y > $bottom } {
            $winName.c yview scroll 1 unit
            event generate $winName.c <B1-Motion> \
                    -x $x -y $y \
                    -when tail
        }

        if { $y < $top } {
            $winName.c yview scroll -1 unit
            event generate $winName.c <B1-Motion> \
                    -x $x -y $y \
                    -when tail
        }


        if { ![info exists sag::windows($winName,anchor)] } {
            return
        }

        # Check to see if the bounding rectangle has
        # changed
        if { ($index == $sag::windows($winName,end)) } {
            return
        }

        set sag::windows($winName,end) $index

        
        set index1 $sag::windows($winName,anchor)
        set index2 $sag::windows($winName,end)

        if { $index2 < $index1 } {
            set tmp $index1
            set index1 $index2
            set index2 $tmp
        }

        $winName.c delete rangehighlight


    }

    sag::hilight $winName $index1 $index2 rangehighlight
}

# sag::reset_scrollregtion --
#     Recaclulated the scroll region allowed by the canvas.
proc sag::reset_scrollregion { winName } {
    set lineheight $sag::windows($winName,lineheight)
    set num [llength $sag::windows($winName,displaylist)]
    set height [expr ($lineheight * $num) ]
    set width [winfo width $winName.c]

    $winName.c configure -scrollregion [list 0 0 $width $height]
    $winName.c configure -yscrollincrement [expr int($lineheight / 2)]
}

# sag::yview_set --
#     Prevent the canvas from being scrolled to far up or down.

proc sag::yview_set { canvas cmd args } {
    if { [string compare $cmd "scroll"] == 0 } {
        foreach {off frac} [$canvas yview] {}
        if { $off != 0.0 || $frac != 1.0 } {
                set start [lindex $args 0]
                set dir [lindex $args 1]
                $canvas yview scroll $start $dir
        }
        return
    }

    if { [string compare $cmd "moveto"] == 0 } {
        set frac [lindex $args 0]
        if {([lindex [$canvas yview] 0] == "0") && ($frac < 0)} {
            return
        }
        $canvas yview moveto $frac
        return
    }
}
