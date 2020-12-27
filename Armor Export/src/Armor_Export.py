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
    
    cur_width, cur_height = img.size
    if cur_width > 400 or cur_height > 400:
        scale = min(400/cur_height, 400/cur_width)
        img = img.resize((int(cur_width*scale), int(cur_height*scale)), Image.ANTIALIAS)
    
    bio = BytesIO()
    img.save(bio, format="PNG")
    del img
    image_cache[url] = bio.getvalue()
    return image_cache[url]

images_col = [
    [sg.Text('Images')],
    [sg.Listbox(images, size=(40,10), key='-LIST-')],
    [
        sg.Button('Remove selected', key='Remove'),
        sg.Button('Preview selected', key='Preview')
    ]
]

preview_col = [
    [sg.Image(data=image_data(images[0]), key='-PREVIEW-')]
]

layout = [
    [sg.Text("Image URL")],
    [
        sg.Input(key='-INPUT-'),
        sg.Button('Add'),
        sg.Button('Preview', key='PreviewInput')
    ],
    [sg.Column(images_col), sg.Column(preview_col)],
    [sg.Button('Quit')]
]

window = sg.Window('Armor Export', layout)

while True:
    event, values = window.read()

    if event == sg.WINDOW_CLOSED or event == 'Quit':
        break

    elif event == 'Add':
        input = values['-INPUT-']
        if not input in images:
            images.append(input)
    elif event == 'Remove':
        [images.remove(x) for x in values['-LIST-']]
    elif event == 'Preview':
        selection = values['-LIST-']
        if len(selection) > 0:
            window['-PREVIEW-'].update(data=image_data(selection[0]))
    elif event == 'PreviewInput':
        input = values['-INPUT-']
        window['-PREVIEW-'].update(data=image_data(input))

    window['-LIST-'].update(images)

window.close()

