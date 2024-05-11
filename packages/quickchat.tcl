# QuickChat Package
#
# All packages must be inside a namespace with the
# same name as the file name.

# Set VERSION and VERSDATE using the CVS tags.
namespace eval quickchat {     
  regexp -- {[0-9]+\.[0-9]+} {@(#)TiK Quick Chat package $Revision: 1.2 $} \
      ::quickchat::VERSION
  regexp -- { .* } {:$Date: 1999/02/08 14:52:10 $} \
      ::quickchat::VERSDATE
}

namespace eval quickchat {

    variable info

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline register sakla

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        menu .quickChatMenu -tearoff 0
        .toolsMenu add cascade -label "Hizli Chat" -menu .quickChatMenu
        .quickChatMenu add command -label "Yeni Hizli Chat" \
                              -command quickchat::create_newquickchat
        .quickChatMenu add separator
        .quickChatMenu add command -label "I-Que Söyleþi" \
                              -command [list quickchat::go "IQue" 4]
    }

    # All pacakges must have goOnline routine.  Called when the user signs
    # on, or if the user is already online when packages loaded.
    proc goOnline {} {
    }

    # All pacakges must have goOffline routine.  Called when the user signs
    # off.  NOT called when the package is unloaded.
    proc goOffline {} {
    }

    # All packages must have a unload routine.  This should remove everything 
    # the package set up.  This is called before load is called when reloading.
    proc unload {} {
        .toolsMenu delete "Hizli Chat"
        destroy .quickChatMenu
        destroy .newquickchat
    }

    # quickchat::register
    #
    # Arguments:
    #    title    - What to show in the menu
    #    room     - The actual room name
    #    exchange - The exchange the chat room is in, usually 4 for now.
    proc register {title room {exchange 4}} {
        catch {.quickChatMenu delete $title}
        .quickChatMenu add command -label $title -command [list quickchat::go $room $exchange]
    }

    proc go {room exchange} {
        tc_chat_join $::KULLANICI $exchange $room
    }

    proc newquickchat_ok {} {
        if {![winfo exists .newquickchat]} {
            return
        }
        quickchat::register $quickchat::info(title) $quickchat::info(room) \
                       $quickchat::info(exchange)
        destroy .newquickchat
    }

    proc sakla { title room exchange } {
        set quickchat::info(title) $title
        set quickchat::info(room) $room
        set quickchat::info(exchange) $exchange
        quickchat::register $quickchat::info(title) $quickchat::info(room) \
                       $quickchat::info(exchange)
    }

    proc create_newquickchat {} {
        set w .newquickchat

        if {[winfo exists $w]} {
            raise $w
            return
        }

        toplevel $w -class Takas
        wm title $w "Yeni Hizli Chat"
        wm iconname $w "Yeni Hizli Chat"
        if {$::IQUE(options,windowgroup)} {wm group $w .login}

        label $w.info -text "Bu yeni soylesi ortami dosyaya yazilmaz"

        set quickchat::info(title) ""
        set quickchat::info(room) ""
        set quickchat::info(exchange) "4"

        frame $w.titleF
        label $w.titleL -text "Menu Basligi:" -anchor se -width 18
        entry $w.titleE -text quickchat::info(title)
        pack $w.titleL $w.titleE -in $w.titleF -side left

        frame $w.roomF
        label $w.roomL -text "Chat Odasi:" -anchor se -width 18
        entry $w.roomE -text quickchat::info(room)
        pack $w.roomL $w.roomE -in $w.roomF -side left

        frame $w.exchangeF
        label $w.exchangeL -text "Degisim:" -anchor se -width 18
        entry $w.exchangeE -text quickchat::info(exchange)
        pack $w.exchangeL $w.exchangeE -in $w.exchangeF -side left

        frame $w.buttons
        button $w.ok -text "Tamam" -command "quickchat::newquickchat_ok"
        button $w.cancel -text "Vazgec" -command [list destroy $w]
        pack $w.ok $w.cancel -in $w.buttons -side left -padx 2m

        pack $w.info $w.titleF $w.roomF $w.exchangeF -side top
        pack $w.buttons -side bottom
    }
}
