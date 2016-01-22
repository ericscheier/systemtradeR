from Tkinter import *

root = Tk()
root.title('Root')
root.geometry('400x200')
rootlabel = Label(root, text = 'This is the OrderBook', relief = RIDGE)
rootlabel.pack(side = TOP, fill = BOTH, expand = YES)

# text = Text(root)
# scrollbar = Scrollbar(root)
# scrollbar.pack(side=RIGHT, fill=Y)

# text.insert(INSERT, "Line 1")
# text.pack()
# scrollbar.config(command=text.yview)
# text.config(yscrollcommand=scrollbar.set)

area = Frame(height=25, bd=1, relief=SUNKEN)
area.pack()
area.columnconfigure(1, weight=1)
area.columnconfigure(3, pad=7)
area.rowconfigure(3, weight=1)
area.rowconfigure(5, pad=7)

bidslistbox = Listbox(area)
#bidslistbox.title("Windows")
bidslistbox.insert(END, "bids")

for item in ["one", "two", "three", "four"]:
    bidslistbox.insert(END, item)
bidslistbox.grid(row=1,column=0)

askslistbox = Listbox(area)
#askslistbox.title("Windows")
askslistbox.insert(END, "asks")

for item in ["one", "two", "three", "four"]:
    askslistbox.insert(END, item)
askslistbox.grid(row=1,column=5)

# w = Canvas(root)
# w.pack()

# textarea = w.create_text(2,3,text="This is Line1",justify="left")

# w.create_line(0, 0, 200, 100)
# w.create_line(0, 100, 200, 0, fill="red", dash=(4, 4))

# w.create_rectangle(50, 25, 150, 75, fill="blue")
root.mainloop()
