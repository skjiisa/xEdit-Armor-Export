import PySimpleGUI as sg
import requests
import re
import json
import os
from PIL import Image, ImageTk
from io import BytesIO
# Must be the MyQR fork at https://github.com/Isvvc/qrcode/
from MyQR import myqr

# Support HiDPI
import ctypes
import platform
if int(platform.release()) >= 8:
    ctypes.windll.shcore.SetProcessDpiAwareness(True)

# Load the JSON file
try:
    with open('Armor Export\\Ingredients.json', 'r') as json_file:
        json_data = json_file.read()
    ingredients = json.loads(json_data)
    print(ingredients['modules'][0]['name'])
except:
    # If no JSON file found, allow the user to paste in JSON
    json_layout = [
        [sg.Text('Ingredients.json not found. Enter JSON:')],
        [sg.Multiline(enter_submits=True, focus=True, size=(80,20), key='-JSON-')],
        [sg.Button('Continue')]
    ]
    json_window = sg.Window('Enter JSON', json_layout, finalize=True)
    event, values = json_window.read(close=True)
    if event == sg.WINDOW_CLOSED:
        del json_window, event, values
        exit()
    
    # Load the JSON
    try:
        ingredients = json.loads(values['-JSON-'])
    except:
        sg.popup('Invalid JSON')
        exit()
    
    # Check that there's a module in the JSON
    if 'modules' in ingredients:
        if len(ingredients['modules']) < 1:
            sg.popup('No modules found')
            quit()
        del json_window, event, values
    else:
        sg.popup('Invalid JSON')
        exit()

images = []
image_cache = dict()

nexus_images = []
nexus_images_loaded = 0

def image_preview(img):
    cur_width, cur_height = img.size
    if cur_width > 400 or cur_height > 400:
        scale = min(400/cur_height, 400/cur_width)
        return img.resize((int(cur_width*scale), int(cur_height*scale)), Image.ANTIALIAS)
    return img

def image_data(url: str) -> bytes:
    if url in image_cache:
        return image_cache[url]
    try:
        data = BytesIO(requests.get(url).content)
        img = Image.open(data)
        
        img = image_preview(img)
        
        bio = BytesIO()
        img.save(bio, format='PNG')
        del img
        image_cache[url] = bio.getvalue()
        return image_cache[url]
    except:
        return None

def make_images_window(current_images):
    global nexus_images_loaded
    image_links = []
    if current_images:
        image_links = images
    else:
        nexus_images_loaded += 5
        image_links = [image[1] for image in nexus_images[:nexus_images_loaded]]
    
    col = sg.Column([[
        sg.Checkbox('', key=f'Checkbox{index}'),
        sg.Image(data=image_data(image), enable_events=True, key=f'Image{index}')
    ] for index, image in enumerate(image_links)], size=(500,1000), scrollable=True, vertical_scroll_only=True)
    
    if not current_images:
        col.add_row(sg.Button('Load 5 more', key='LoadMore'))
        col.set_vscroll_position((nexus_images_loaded - 5) / nexus_images_loaded)
    
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
    [sg.Button('Set as QR background', key='SetBackground')],
    [sg.Column(images_col), sg.Column(preview_col)],
    [sg.Text("Save images to")],
    [
        sg.Button('Module', key='SaveModule'),
        sg.Button('Mod', key='SaveMod'),
        sg.Button('Both', key='SaveBoth'),
        sg.Checkbox('Generate QR code', default=True, key='GenerateQR')
    ],
    [sg.Text('QR Code Background Image')],
    [
        sg.Input(key='-BACKGROUND-', disabled=True), 
        sg.Button('Clear'),
        sg.Button('Select File')
    ],
    [sg.Col([
        [sg.Text('QR codes with background images take a long time to generate.')],
        [sg.Text('QR codes with backgrounds can be hard to scan. Test before publishing.')]
    ], visible=False, key='-WARNINGS-')],
    [
        sg.Button('Quit'),
        sg.Button('Open Armor Export folder', key='ArmorExportFolder')
    ]
]

window = sg.Window('Armor Export', layout, finalize=True)
images_window = None

background_url = None
background_file = None

def update_module_images():
    global images, ingredients
    try:
        if len(images) > 0:
            ingredients['modules'][0]['images'] = images.copy()
        elif 'images' in ingredients['modules'][0]:
            ingredients['modules'][0].pop('images')
        return True
    except:
        sg.popup('No module found in JSON')
        return False

def update_mod_images():
    global images, ingredients
    try:
        if len(images) > 0:
            ingredients['mods'][0]['images'] = images.copy()
        elif 'images' in ingredients['mods'][0]:
            ingredients['mods'][0].pop('images')
        return True
    except:
        sg.popup('No mod found in JSON')
        return False

def save_ingredients():
    global ingredients, window, background_url, background_file
    ingredients_json = json.dumps(ingredients)
    
    try:
        # Check that Ingredients.json already exists before creating one.
        with open('Armor Export\\Ingredients.json') as f: pass
        with open('Armor Export\\Ingredients.json', 'w') as json_file:
            json_file.write(ingredients_json)
    except: pass

    if window['GenerateQR'].get():
        if background_url and not background_file:
            # Fetch background image
            try:
                data = BytesIO(requests.get(background_url).content)
                img = Image.open(data)
                path = 'Armor Export\\bg.png'
                img.save(path)
                background_file = path
            except: pass
        
        myqr.run(ingredients_json, level='L', picture=background_file, colorized=True, save_name='qrcode.png', save_dir='Armor Export')
        
        qr = Image.open('Armor Export\\qrcode.png')
        img = image_preview(qr)
        bio = BytesIO()
        img.save(bio, format='PNG')
        del img
        window['-PREVIEW-'].update(data=bio.getvalue())
        
        if background_url:
            # Delete the saved background image
            try: os.remove('Armor Export\\bg.png')
            except: pass

while True:
    active_window, event, values = sg.read_all_windows()
    print(event)
    
    if (event == sg.WINDOW_CLOSED and active_window == window) or event == 'Quit':
        break

    elif event == 'Add':
        input = values['-URL_INPUT-']
        if not input in images and not input == '':
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
            try:
                response = requests.get(url)
                if not 'html' in response.headers['Content-Type']:
                    sg.popup('Not a valid webpage.')
                    continue
                html = response.text
                nexus_images = re.findall('data-src="([^"]*)" data-sub-html="" data-exthumbimage="([^"]*)"', html)
                if len(nexus_images) > 0:
                    nexus_images_loaded = 0
                    images_window = make_images_window(current_images=False)
                else:
                    sg.popup('Not a valid Nexusmods mod page.')
            except:
                sg.popup('Invalid URL')
        
    elif 'Image' in event:
        # 'Image' has 5 characters, so remove the first 5 characters to get the index
        index = event[5:]
        images_window[f'Checkbox{index}'].update(not images_window[f'Checkbox{index}'].get())
    
    elif event == 'AddNexus':
        [images.append(nexus_images[i][0]) for i in range(min(len(nexus_images), nexus_images_loaded)) if images_window[f'Checkbox{i}'].get() and not nexus_images[i][0] in images]
        window['-LIST-'].update(images)
        images_window.close()
        images_window = None
    
    elif event == 'LoadMore':
        images_window.close()
        images_window = None
        images_window = make_images_window(current_images=False)
    
    elif event == 'RemoveCurrent':
        [images.pop(i) for i in reversed(range(len(images))) if images_window[f'Checkbox{i}'].get()]
        window['-LIST-'].update(images)
        images_window.close()
        images_window = make_images_window(current_images=True)
    
    elif event == 'SaveModule':
        update_module_images() and \
        save_ingredients()
    
    elif event == 'SaveMod':
        update_mod_images() and \
        save_ingredients()
    
    elif event == 'SaveBoth':
        update_module_images() and \
        update_mod_images() and \
        save_ingredients()
    
    elif event == 'SetBackground':
        background_url = values['-URL_INPUT-']
        background_file = None
        window['-BACKGROUND-'].update(background_url)
        window['-WARNINGS-'].update(visible=True)
    
    elif event == 'Select File':
        background_file = sg.popup_get_file('Background image file', file_types=(('Images', '*.png *.jpg *.jpeg *.bmp *.gif'),))
        background_url = None
        window['-BACKGROUND-'].update(background_file)
        window['-WARNINGS-'].update(visible=True)
    
    elif event == 'Clear':
        background_file = None
        background_url = None
        window['-BACKGROUND-'].update('')
        window['-WARNINGS-'].update(visible=False)
    
    elif event == 'ArmorExportFolder':
        path = os.path.realpath('Armor Export')
        os.startfile(path)

window.close()
