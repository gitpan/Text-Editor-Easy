#
# Let's see an interactive application,
# the macro panel of the Editor
# program.
#
# It may be used to :
#    - debug (requests on data followed
#      by a display : to be in an editor
#      can sometimes be helpful)
#    - learn the interface of the Text::Editor::Easy
#      module interactively
#    - extend the editor or configure it...
#    - debug (Don't tell me !)
#
# Be careful, this demo (and the
# following ones) can't be executed
# alone as an autonomous program
# (you have to be in the Editor program)
#
# Pressing F5 will clean the "macro panel"
# and will insert macro instructions
# to be executed (at the bottom)
#
# As the "macro panel" is sensible to "insert"
# event, the macro instructions
# will be automatically executed
#
# The execution of these macro instructions
# will display results in the "Eval_out" panel
# (= standard out of macro processing) :
# on the middle right panel
#
# The actions of the macro instructions
# modify the 'stack_calls' Text::Editor::Easy object
# which is the bottom right panel
#
# Once F5 has been pressed, you can
# modify the macro-instructions.
# The execution will follow after insertion
# event (and only : well, it's not a
# bug ! it's just version 0.01)
#
# Now, you can try any perl code insertion
# and see in "real time" the execution of
# the code. Well, this may be dangerous but
# this is only a dangerous demo.
#
