#############################################################################
# Visual Tcl v1.20 Project
#

proc {Window} {args} {
global vTcl
    set cmd [lindex $args 0]
    set name [lindex $args 1]
    set newname [lindex $args 2]
    set rest [lrange $args 3 end]
    if {$name == "" || $cmd == ""} {return}
    if {$newname == ""} {
        set newname $name
    }
    set exists [winfo exists $newname]
    switch $cmd {
        show {
            if {$exists == "1" && $name != "."} {wm deiconify $name; return}
            if {[info procs vTclWindow(pre)$name] != ""} {
                eval "vTclWindow(pre)$name $newname $rest"
            }
            if {[info procs vTclWindow$name] != ""} {
                eval "vTclWindow$name $newname $rest"
            }
            if {[info procs vTclWindow(post)$name] != ""} {
                eval "vTclWindow(post)$name $newname $rest"
            }
        }
        hide    { if $exists {wm withdraw $newname; return} }
        iconify { if $exists {wm iconify $newname; return} }
        destroy { if $exists {destroy $newname; return} }
    }
}

#################################
# VTCL GENERATED GUI PROCEDURES
#

proc vTclWindow. {base} {
    if {$base == ""} {
        set base .
    }
    ###################
    # CREATING WIDGETS
    ###################
    wm focusmodel $base passive
    wm geometry $base 200x200+0+0
    wm maxsize $base 1028 753
    wm minsize $base 104 1
    wm overrideredirect $base 0
    wm resizable $base 1 1
    wm withdraw $base
    wm title $base "vt"
    ###################
    # SETTING GEOMETRY
    ###################
}

proc vTclWindow.top17 {base} {
    if {$base == ""} {
        set base .top17
    }
    if {[winfo exists $base]} {
        wm deiconify $base; return
    }
    set ::kayit(cik) 0
    ###################
    # CREATING WIDGETS
    ###################
    toplevel $base -class Toplevel
    wm focusmodel $base passive
    wm geometry $base 545x346
    wm maxsize $base 1028 753
    wm minsize $base 104 1
    wm overrideredirect $base 0
    wm resizable $base 1 1
    wm deiconify $base
    wm title $base "New Toplevel 1"
    label $base.lab18 \
        -borderwidth 1 -relief raised -text {Kayýt Ýþlemleri} 
    frame $base.fra19 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    label $base.fra19.lab22 \
        -anchor w -borderwidth 1 -justify right -relief raised \
        -text { Kullanýcý Adý} 
    label $base.fra19.lab23 \
        -anchor w -borderwidth 1 -relief raised -text { Þifre} 
    label $base.fra19.lab24 \
        -anchor w -borderwidth 1 -relief raised -text { Þifre Onayý} 
    entry $base.fra19.ent25 -font $::NORMALFONT -textvariable ::KULLAN
    entry $base.fra19.ent26 -font $::NORMALFONT \
          -textvariable ::PASSWORD -show "*"
    entry $base.fra19.ent27 -font $::NORMALFONT \
          -textvariable ::PASSWORD1 -show "*"
    frame $base.fra38 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    label $base.fra38.lab40 \
        -anchor w -borderwidth 1 -relief raised -text { E-Posta Adresi} 
    label $base.fra38.lab39 \
        -anchor w -borderwidth 1 -relief raised -text { Grup Adý} 
    kayitoptions $base.fra38.ent45 sinif $::kayit(siniflar)
    entry $base.fra38.ent46 -font $::NORMALFONT -textvariable ::kayit(eposta)
    frame $base.fra20 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    label $base.fra20.lab28 \
        -borderwidth 1 -relief raised -text {Ad ve Soyad} 
    label $base.fra20.lab30 \
        -borderwidth 1 -relief raised -text Cinsiyet 
    label $base.fra20.lab31 \
        -borderwidth 1 -relief raised -text Öðrenim 
    label $base.fra20.lab32 \
        -borderwidth 1 -relief raised -text {Medeni Durum} 
    label $base.fra20.lab33 \
        -borderwidth 1 -relief raised -text Meslek 
    label $base.fra20.lab34 \
        -borderwidth 1 -relief raised -text Þehir 
    label $base.fra20.lab36 \
        -borderwidth 1 -relief raised -text {Doðum Tarihi} 
    label $base.fra20.lab37 \
        -borderwidth 1 -relief raised -text Ülke 
    frame $base.fra21 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    entry $base.fra20.ent47 -font $::NORMALFONT -textvariable ::kayit(adsoyad)
    kayitoptions $base.fra20.ent48 cins $::kayit(cinsler)
    kayitoptions $base.fra20.ent49 ogrenim $::kayit(ogrenimler)
    kayitoptions $base.fra20.ent50 mdurum $::kayit(mdurumlar)
    kayitoptions $base.fra20.ent51 meslek $::kayit(meslekler)
    entry $base.fra20.ent58 -font $::NORMALFONT -textvariable ::kayit(gun)
    entry $base.fra20.ent55 -font $::NORMALFONT -textvariable ::kayit(ay)
    entry $base.fra20.ent54 -font $::NORMALFONT -textvariable ::kayit(yil)
    entry $base.fra20.ent52 -font $::NORMALFONT -textvariable ::kayit(sehir)
    kayitoptions $base.fra20.ent53 ulke $::kayit(ulkeler)
    checkbutton $base.fra21.che62 \
        -text I-Que -variable ::kayit(ique) 
    checkbutton $base.fra21.che63 \
        -text Abonelik -variable ::kayit(abone) 
    button $base.fra21.but64 \
        -text Yardým -command ique_yardim
    button $base.fra21.but61 \
        -text Gönder -command ique_kayit
    button $base.fra21.but60 \
        -text {Eski Kayýt}  -command { destroy .top17 }
    button $base.fra21.but59 \
        -text Vazgeç -command { set ::kayit(cik) 1; destroy .top17 }
    frame $base.fra65 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    label $base.fra65.label -relief raised -text "Proxy:"

    menubutton $base.fra65.proxies -textvariable ::USEPROXY -indicatoron 1 \
            -menu $base.fra65.proxies.menu \
            -relief raised -bd 2 -highlightthickness 2 -anchor c \
            -direction flush
    menu $base.fra65.proxies.menu -tearoff 0

    ique_register_proxy Yok "" "ique_noneproxy_config" $base.fra65.proxies.menu

    button $base.fra65.config -text Tanýmla -command \
        {$::IQUE(proxies,$::USEPROXY,configFunc)}
    pack $base.fra65.label $base.fra65.proxies $base.fra65.config \
         -in $base.fra65 -side left -expand 1
    ###################
    # SETTING GEOMETRY
    ###################
    place $base.lab18 \
        -x 5 -y 5 -width 536 -height 27 -anchor nw -bordermode ignore 
    place $base.fra19 \
        -x 5 -y 40 -width 235 -height 100 -anchor nw -bordermode ignore 
    place $base.fra19.lab22 \
        -x 5 -y 5 -width 101 -height 27 -anchor nw -bordermode ignore 
    place $base.fra19.lab23 \
        -x 5 -y 35 -width 101 -height 27 -anchor nw -bordermode ignore 
    place $base.fra19.lab24 \
        -x 5 -y 65 -width 101 -height 27 -anchor nw -bordermode ignore 
    place $base.fra19.ent25 \
        -x 117 -y 6 -width 106 -height 24 -anchor nw -bordermode ignore 
    place $base.fra19.ent26 \
        -x 117 -y 36 -width 106 -height 24 -anchor nw -bordermode ignore 
    place $base.fra19.ent27 \
        -x 117 -y 65 -width 106 -height 24 -anchor nw -bordermode ignore 
    place $base.fra38 \
        -x 5 -y 145 -width 235 -height 100 -anchor nw -bordermode ignore 
    place $base.fra38.lab39 \
        -x 5 -y 17 -width 106 -height 22 -anchor nw -bordermode ignore 
    place $base.fra38.lab40 \
        -x 5 -y 51 -width 106 -height 22 -anchor nw -bordermode ignore 
    place $base.fra38.ent45 \
        -x 120 -y 18 -width 106 -height 19 -anchor nw -bordermode ignore 
    place $base.fra38.ent46 \
        -x 120 -y 51 -width 106 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20 \
        -x 245 -y 40 -width 295 -height 205 -anchor nw -bordermode ignore 
    place $base.fra20.lab28 \
        -x 5 -y 5 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab30 \
        -x 5 -y 29 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab31 \
        -x 5 -y 79 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab32 \
        -x 5 -y 104 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab33 \
        -x 5 -y 128 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab34 \
        -x 5 -y 151 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab36 \
        -x 5 -y 54 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.lab37 \
        -x 5 -y 175 -width 121 -height 22 -anchor nw -bordermode ignore 
    place $base.fra20.ent47 \
        -x 135 -y 5 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent48 \
        -x 135 -y 29 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent49 \
        -x 135 -y 79 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent50 \
        -x 135 -y 105 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent51 \
        -x 135 -y 128 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent52 \
        -x 135 -y 153 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent53 \
        -x 135 -y 176 -width 151 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent54 \
        -x 235 -y 53 -width 51 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent55 \
        -x 187 -y 53 -width 31 -height 19 -anchor nw -bordermode ignore 
    place $base.fra20.ent58 \
        -x 136 -y 53 -width 31 -height 19 -anchor nw -bordermode ignore 
    place $base.fra21 \
        -x 5 -y 250 -width 535 -height 40 -anchor nw -bordermode ignore 
    place $base.fra21.but59 \
        -x 460 -y 5 -anchor nw -bordermode ignore 
    place $base.fra21.but60 \
        -x 390 -y 5 -width 61 -height 28 -anchor nw -bordermode ignore 
    place $base.fra21.but61 \
        -x 330 -y 5 -anchor nw -bordermode ignore 
    place $base.fra21.che62 \
        -x 5 -y 5 -anchor nw -bordermode ignore 
    place $base.fra21.che63 \
        -x 75 -y 5 -anchor nw -bordermode ignore 
    place $base.fra21.but64 \
        -x 155 -y 5 -anchor nw -bordermode ignore 
    place $base.fra65 \
        -x 5 -y 295 -width 535 -height 45 -anchor nw -bordermode ignore 
}

proc vTclWindow.sresult {base} {
    if {$base == ""} {
        set base .sresult
    }
    if {[winfo exists $base]} {
        wm deiconify $base; return
    }
    ###################
    # CREATING WIDGETS
    ###################
    toplevel $base -class Toplevel
    wm focusmodel $base passive
    wm geometry $base 400x230
    wm maxsize $base 1028 753
    wm minsize $base 104 1
    wm overrideredirect $base 0
    wm resizable $base 1 1
    wm deiconify $base
    wm title $base "Arama Sonuçlarý"
    frame $base.fra18 \
        -borderwidth 2 -height 75 -relief groove -width 125 
    frame $base.fra18.cpd21 \
        -borderwidth 1 -height 30 -relief raised -width 30 
    listbox $base.fra18.cpd21.01 \
        -font -Adobe-Helvetica-Medium-R-Normal-*-*-120-*-*-*-*-*-* \
        -yscrollcommand {.sresult.fra18.cpd21.03 set} 
    scrollbar $base.fra18.cpd21.03 \
        -borderwidth 1 -command {.sresult.fra18.cpd21.01 yview} -orient vert \
        -width 10 
    button $base.but19 \
        -text Ekle \
        -command { selected_user [.sresult.fra18.cpd21.01 curselection] }
    button $base.but20 \
        -text Vazgec  -command { destroy .sresult }
    ###################
    # SETTING GEOMETRY
    ###################
    place $base.fra18 \
        -x 5 -y 5 -width 395 -height 180 -anchor nw -bordermode ignore 
    place $base.fra18.cpd21 \
        -x 5 -y 5 -width 385 -height 170 -anchor nw -bordermode ignore 
    grid columnconf $base.fra18.cpd21 0 -weight 1
    grid rowconf $base.fra18.cpd21 0 -weight 1
    grid $base.fra18.cpd21.01 \
        -in .sresult.fra18.cpd21 -column 0 -row 0 -columnspan 1 -rowspan 1 \
        -sticky nesw 
    grid $base.fra18.cpd21.03 \
        -in .sresult.fra18.cpd21 -column 1 -row 0 -columnspan 1 -rowspan 1 \
        -sticky ns 
    place $base.but19 \
        -x 305 -y 195 -anchor nw -bordermode ignore 
    place $base.but20 \
        -x 345 -y 195 -anchor nw -bordermode ignore 
}

proc create_kayitol {} {
     Window show .top17
}

proc create_searchwin {} {
     Window show .sresult
}
