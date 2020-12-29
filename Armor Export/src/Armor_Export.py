import PySimpleGUI as sg
import requests
import re
from PIL import Image, ImageTk
from io import BytesIO

# Support HiDPI
import ctypes
import platform
if int(platform.release()) >= 8:
    ctypes.windll.shcore.SetProcessDpiAwareness(True)

images = []
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
    img.save(bio, format='PNG')
    del img
    image_cache[url] = bio.getvalue()
    return image_cache[url]

def make_images_window(images):
    col = sg.Column([[
        sg.Checkbox('', key=f'Checkbox{index}'),
        sg.Image(data=image_data(image), enable_events=True, key=f'Image{index}')
    ] for index, image in enumerate(images)], size=(500,1000), scrollable=True)
    images_layout = [[col]]
    new_window = sg.Window('Images', images_layout, finalize=True)
    return new_window

images_col = [
    [sg.Text('Images')],
    [sg.Listbox(images, size=(40,10), key='-LIST-')],
    [
        sg.Button('Remove selected', key='Remove'),
        sg.Button('Preview selected', key='Preview'),
        sg.Button('Preview all', key='PreviewAll')
    ]
]

preview_col = [
    [sg.Image(data=image_data("https://upload.wikimedia.org/wikipedia/en/1/15/The_Elder_Scrolls_V_Skyrim_cover.png"), key='-PREVIEW-')]
]

layout = [
    [sg.Text("Nexusmods URL")],
    [
        sg.Input(key='-NEXUS_INPUT-'),
        sg.Button('Open')
    ],
    [sg.Text("Image URL")],
    [
        sg.Input(key='-URL_INPUT-'),
        sg.Button('Add'),
        sg.Button('Preview', key='PreviewInput')
    ],
    [sg.Column(images_col), sg.Column(preview_col)],
    [sg.Button('Quit')]
]

window = sg.Window('Armor Export', layout, finalize=True)
images_window = None

while True:
    active_window, event, values = sg.read_all_windows()
    print(event)
    if (event == sg.WINDOW_CLOSED and active_window == window) or event == 'Quit':
        break

    elif event == 'Add':
        input = values['-URL_INPUT-']
        if not input in images:
            images.append(input)
            window['-LIST-'].update(images)
    
    elif event == 'Remove':
        [images.remove(x) for x in values['-LIST-']]
        window['-LIST-'].update(images)
    
    elif event == 'Preview':
        selection = values['-LIST-']
        if len(selection) > 0:
            window['-PREVIEW-'].update(data=image_data(selection[0]))
    
    elif event == 'PreviewInput':
        input = values['-URL_INPUT-']
        window['-PREVIEW-'].update(data=image_data(input))
    
    elif event == 'PreviewAll':
        if images_window is None:
            images_window = make_images_window(images)
        
    elif event == sg.WINDOW_CLOSED and active_window == images_window:
        images_window.close()
        images_window = None
    
    elif event == 'Open':
        if images_window is None:
            url = values['-NEXUS_INPUT-']
            html = requests.get(url).text
            matches = re.findall('data-src="([^"]*)" data-sub-html="" data-exthumbimage="([^"]*)"', html)
            thumbnails = [match[1] for match in matches[:5]]
            images_window = make_images_window(thumbnails)
        
    elif "Image" in event:
        index = event[5:]
        images_window[f'Checkbox{index}'].update(not images_window[f'Checkbox{index}'].get())

window.close()
