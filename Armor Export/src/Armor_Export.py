import PySimpleGUI as sg
import requests
from PIL import Image, ImageTk
from io import BytesIO

# Support HiDPI
import ctypes
import platform
if int(platform.release()) >= 8:
    ctypes.windll.shcore.SetProcessDpiAwareness(True)

images = ["https://upload.wikimedia.org/wikipedia/en/1/15/The_Elder_Scrolls_V_Skyrim_cover.png"]
image_cache = dict()

def image_data(url: str) -> bytes:
    if url in image_cache:
        return image_cache[url]
    data = BytesIO(requests.get(url).content)
    img = Image.open(data)
    bio = BytesIO()
    img.save(bio, format="PNG")
    del img
    image_cache[url] = bio.getvalue()
    return image_cache[url]

# Define the window's contents
layout = [
    [sg.Text("Image URL")],
    [sg.Input(key='-INPUT-'), sg.Button('Add')],
    [sg.Text('Images')],
    [sg.Listbox(images, size=(40,10), select_mode=sg.LISTBOX_SELECT_MODE_MULTIPLE, key='-LIST-')],
    [sg.Button('Remove selected', key='Remove')],
    #[sg.Image(data=image_data(images[0]))],
    [sg.Button('Quit')]
]

# Create the window
window = sg.Window('Window Title', layout)

# Display and interact with the Window using an Event Loop
while True:
    event, values = window.read()

    # See if user wants to quit or window was closed
    if event == sg.WINDOW_CLOSED or event == 'Quit':
        break

    elif event == 'Add':
        input = values['-INPUT-']
        if not input in images:
            images.append(input)
    elif event == 'Remove':
        [images.remove(x) for x in values['-LIST-']]

    window['-LIST-'].update(images)

# Finish up by removing from the screen
window.close()

