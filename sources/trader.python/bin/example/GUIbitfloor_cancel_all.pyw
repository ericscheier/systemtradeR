#!/usr/bin/env python
#creating a python GUI with TKinter
#http://www.pythonware.com/library/tkinter/introduction/
#http://www.pythonware.com/library/tkinter/introduction/tkinter-reference.htm
#http://www.tutorialspoint.com/python/python_gui_programming.htm

import bitfloorapi
from sys import exit
from Tkinter import *
import tkMessageBox
import tkSimpleDialog 

class StatusBar(Frame):

    def __init__(self, master):
        Frame.__init__(self, master)
        self.label = Label(self, bd=1, relief=SUNKEN, anchor=W)
        self.label.pack(fill=X)

    def set(self, format, *args):
        self.label.config(text=format % args)
        self.label.update_idletasks()

    def clear(self):
        self.label.config(text="")
        self.label.update_idletasks()





#buncha message boxes. (message,title)
#showinfo,showwarning,showerror
# i, !, X
def say_hi():
    tkMessageBox.showinfo(
            "Hello World",
            "hi there, everyone!"
        )

def callback():
    tkMessageBox.showinfo(
            "Callback",
            "called the callback!"
        )


#create the root
root = Tk()

# create a menu
menu = Menu(root)
root.config(menu=menu)

filemenu = Menu(menu)
menu.add_cascade(label="File", menu=filemenu)
filemenu.add_command(label="New", command=callback)
filemenu.add_command(label="Open...", command=callback)
filemenu.add_separator()
filemenu.add_command(label="Exit", command=callback)
#tkFileDialog.askopenfilename([options]).
#tkFileDialog.asksaveasfilename([options]).

helpmenu = Menu(menu)
menu.add_cascade(label="Help", menu=helpmenu)
helpmenu.add_command(label="About...", command=callback)

# create a toolbar
toolbar = Frame(root)

b = Button(toolbar, text="new", width=6, command=callback, state=DISABLED)
b.pack(side=LEFT, padx=2, pady=2)

b = Button(toolbar, text="open", width=6, command=callback, state=DISABLED)
b.pack(side=LEFT, padx=2, pady=2)

toolbar.pack(side=TOP, fill=X)

#create a frame with a few buttons.
frame = Frame(root)
frame.pack()

button = Button(frame, text="QUIT", fg="red", command=frame.quit)
button.pack(side=LEFT)


#prompt for a string
password = tkSimpleDialog.askstring("Bitfloor","Password", parent=root)
#can also do askinteger askfloat
#options = minvalue,maxvalue

#initialize the bitfloor api
bitfloor = bitfloorapi.Client(password)



button = Button(frame, text="BITFLOOR CANCEL ALL", fg="red", command=bitfloor.cancel_all)
button.flash()
button.pack(side=LEFT)


hi_there = Button(frame, text="Hello", command=say_hi)
hi_there.pack(side=LEFT)

#create a status bar
status = StatusBar(root)
status.pack(side=BOTTOM, fill=X)



#askquestion dialog
output = "This is what we wanted to print."
if tkMessageBox.askyesno("Print", "Print this string?"):
    tkMessageBox.showinfo(
        "Output",
        output
    )

#askokcancel
#askyesno
#askretrycancel

#default = ABORT, RETRY, IGNORE, OK, CANCEL, YES, or NO
#icon = ERROR, INFO, QUESTION, WARNING
#parent = widget
#type = Message box type; that is, which buttons to display: ABORTRETRYIGNORE, OK, OKCANCEL, RETRYCANCEL, YESNO, or YESNOCANCEL.


#start the app.
mainloop()