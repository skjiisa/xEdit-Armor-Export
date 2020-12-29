import PySimpleGUI as sg
import requests
import re
import json
from PIL import Image, ImageTk
from io import BytesIO

# Support HiDPI
import ctypes
import platform
if int(platform.release()) >= 8:
    ctypes.windll.shcore.SetProcessDpiAwareness(True)

# Load the json file
with open('ingredients.json', 'r') as json_file:
    json_data = json_file.read()
ingredients = json.loads(json_data)
print(ingredients['modules'][0]['name'])

images = []
image_cache = dict()

nexus_images = []
nexus_images_loaded = 0

def image_data(url: str) -> bytes:
    if url in image_cache:
        return image_cache[url]
    data = BytesIO(requests.get(url).content)
    img = Image.open(data)
    
    cur_width, cur_height = img.size
    # TODO: only scale if the image is larger than this
    # Nexusmods thumbnails are slightly below 400 pixels, so don't need to be resized.
    if cur_width > 400 or cur_height > 400:
        scale = min(400/cur_height, 400/cur_width)
        img = img.resize((int(cur_width*scale), int(cur_height*scale)), Image.ANTIALIAS)
    
    bio = BytesIO()
    img.save(bio, format='PNG')
    del img
    image_cache[url] = bio.getvalue()
    return image_cache[url]

def make_images_window(current_images):
    global nexus_images_loaded
    image_links = []
    if current_images:
        image_links = images
    else:
        image_links = [image[1] for image in nexus_images[:5]]
        nexus_images_loaded = 5
    
    col = sg.Column([[
        sg.Checkbox('', key=f'Checkbox{index}'),
        sg.Image(data=image_data(image), enable_events=True, key=f'Image{index}')
    ] for index, image in enumerate(image_links)], size=(500,1000), scrollable=True)
    
    images_layout = [[
        col,
        sg.Column([
            [sg.Button('Remove', key='RemoveCurrent') if current_images else sg.Button('Add', key='AddNexus')],
            [sg.Button('Done')]
        ], element_justification='center')
    ]]
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
    [sg.Image(key='-PREVIEW-')]
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
    [
        sg.Button('Save images to module', key='SaveModule'),
        sg.Button('Save images to mod', key='SaveMod'),
        sg.Button('Save images to both', key='SaveBoth')
    ],
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
        window['-URL_INPUT-'].update('')
    
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
            images_window = make_images_window(current_images=True)
        
    elif (event == sg.WINDOW_CLOSED and active_window == images_window) or event == 'Done':
        images_window.close()
        images_window = None
    
    elif event == 'Open':
        if images_window is None:
            url = values['-NEXUS_INPUT-']
            html = requests.get(url).text
            nexus_images = re.findall('data-src="([^"]*)" data-sub-html="" data-exthumbimage="([^"]*)"', html)
            images_window = make_images_window(current_images=False)
        
    elif 'Image' in event:
        # 'Image' has 5 characters, so remove the first 5 characters to get the index
        index = event[5:]
        images_window[f'Checkbox{index}'].update(not images_window[f'Checkbox{index}'].get())
    
    elif event == 'AddNexus':
        [images.append(nexus_images[i][0]) for i in range(min(len(nexus_images), nexus_images_loaded)) if images_window[f'Checkbox{i}'].get() and not nexus_images[i][0] in images]
        window['-LIST-'].update(images)
        images_window.close()
        images_window = None
    
    elif event == 'RemoveCurrent':
        [images.pop(i) for i in reversed(range(len(images))) if images_window[f'Checkbox{i}'].get()]
        window['-LIST-'].update(images)
        images_window.close()
        images_window = make_images_window(current_images=True)
    
    elif event == 'SaveModule':
        ingredients['modules'][0]['images'] = images
        with open('ingredients.json', 'w') as json_file:
            json_file.write(json.dumps(ingredients))
    
    elif event == 'SaveMod':
        ingredients['mods'][0]['images'] = images
        with open('ingredients.json', 'w') as json_file:
            json_file.write(json.dumps(ingredients))
    
    elif event == 'SaveBoth':
        ingredients['modules'][0]['images'] = images
        ingredients['mods'][0]['images'] = images
        with open('ingredients.json', 'w') as json_file:
            json_file.write(json.dumps(ingredients))

window.close()
