## Binding keys

###Create mappings:

`/lkamap <type> <name> <macro text or spell name> [<key1>, <key2>, ...]`

`<type>` - the type. Currently only "macro" and "spell" are supported (and "spell" is really just a macro that casts the spell :/).

`<name>` - the name. If the name is "\_", the name will default to the text of the macro.

`<macro text or spell name>` - Self explanatory, I hope!

`<keyN>` - the keys in the sequence. These must be named after their WoW name.

Example: `/lkamap macro Appearances "/script ToggleCollectionsJournal(5)" K C A`.


###Unbind mapping:

`/lkaunmap [<key1>, <key2>, ...]`


###Name a submenu:

`/lkaname <name> [<key1>, <key2>, ...]`


##Binding Scopes:

You can create class-specific and spec-specific binds, using variants of the above commands. Class binds: `/lkclmap`, `/lkclunmap`, `/lkclname`. Spec binds: `/lksmap`, `/lksunmap`, `/lksname`.


##Other notes:

You can cancel a sequence in progress with ESCAPE.

You can't disable the chat spam. Sorry! Will add some nice UI later on, I hope.
