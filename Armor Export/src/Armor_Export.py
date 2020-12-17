import PySimpleGUI as sg

images = {"https://upload.wikimedia.org/wikipedia/en/1/15/The_Elder_Scrolls_V_Skyrim_cover.png"}

# Define the window's contents
layout = [[sg.Text("Image URL")],
          [sg.Input(key='-INPUT-'), sg.Button('Add')],
          [sg.Text('Images')],
          [sg.Listbox(list(images), size=(40,10), select_mode=sg.LISTBOX_SELECT_MODE_MULTIPLE, key='-LIST-')],
          [sg.Button('Remove selected', key='Remove')],
          [sg.Button('Quit')]]

# Create the window
window = sg.Window('Window Title', layout)

# Display and interact with the Window using an Event Loop
while True:
    event, values = window.read()

    # See if user wants to quit or window was closed
    if event == sg.WINDOW_CLOSED or event == 'Quit':
        break

    elif event == 'Add':
        images.add(values['-INPUT-'])
    elif event == 'Remove':
        [images.remove(x) for x in values['-LIST-']]

    window['-LIST-'].update(list(images))

# Finish up by removing from the screen
window.close()

