from PIL import Image, ImageDraw, ImageOps
import requests
from io import BytesIO
import tkinter as tk
from tkinter import filedialog, simpledialog
import validators

# Define the default VS Code background color
VSCODE_BG_COLOR = (30, 30, 30)  # RGB value for VS Code default dark theme

# Define the sizes for different devices
RESOLUTIONS = {
    "Phone Wallpaper": (1080, 1920),
    "Tablet Wallpaper": (2048, 2732),
    "1080p": (1920, 1080)
}

# Function to download image from the web
def download_image(url):
    response = requests.get(url)
    response.raise_for_status()  # Ensure the request was successful
    return Image.open(BytesIO(response.content))

# Function to pixelate the image
def pixelate_image(image, pixel_size):
    small_image = image.resize(
        (image.size[0] // pixel_size, image.size[1] // pixel_size),
        resample=Image.NEAREST
    )
    pixelated_image = small_image.resize(
        image.size,
        Image.NEAREST
    )
    return pixelated_image

# Function to resize image with aspect ratio
def resize_with_aspect_ratio(image, target_size):
    original_ratio = image.size[0] / image.size[1]
    target_ratio = target_size[0] / target_size[1]

    if original_ratio > target_ratio:
        new_width = target_size[0]
        new_height = int(new_width / original_ratio)
    else:
        new_height = target_size[1]
        new_width = int(new_height * original_ratio)

    return image.resize((new_width, new_height), Image.Resampling.LANCZOS)

# Function to crop image to fit the target size
def crop_to_fit(image, target_size):
    return ImageOps.fit(image, target_size, Image.Resampling.LANCZOS)

# Function to handle the pixel art generation based on user options
def generate_pixel_art(image, pixel_size, output_size, resize_option):
    if resize_option == 'stretch':
        input_image = image.resize(output_size, Image.Resampling.LANCZOS)
    elif resize_option == 'aspect_ratio':
        input_image = resize_with_aspect_ratio(image, output_size)
        background_image = Image.new('RGB', output_size, VSCODE_BG_COLOR)
        x_offset = (output_size[0] - input_image.size[0]) // 2
        y_offset = (output_size[1] - input_image.size[1]) // 2
        background_image.paste(input_image, (x_offset, y_offset))
        input_image = background_image
    elif resize_option == 'crop':
        input_image = crop_to_fit(image, output_size)
    elif resize_option == 'original':
        input_image = image

    pixelated_image = pixelate_image(input_image, pixel_size)
    pixelated_image.show()
    pixelated_image.save("pixelated_with_vscode_bg.png")

# Function to get image URL from user and generate pixel art
def generate_art():
    input_value = simpledialog.askstring("Input", "Enter the image URL or local file path:")
    if input_value:
        if validators.url(input_value):
            input_image = download_image(input_value)
        else:
            input_image = Image.open(input_value)

        output_size = RESOLUTIONS[resolution_var.get()]
        generate_pixel_art(input_image, pixel_size_slider.get(), output_size, resize_option_var.get())

# Create the main window
root = tk.Tk()
root.title("iNet's Pixel Art Converter")
root.geometry("400x450")  # Set window size
root.resizable(False, False)  # Make the window non-resizable

# Create and pack the pixelation size slider
pixel_size_slider = tk.Scale(root, from_=1, to_=50, orient=tk.HORIZONTAL, label="Pixelation Size", length=300)
pixel_size_slider.set(10)
pixel_size_slider.pack(pady=10)

# Create a frame for the resolution radio buttons
resolution_frame = tk.LabelFrame(root, text="Select Resolution", padx=10, pady=10)
resolution_frame.pack(pady=10)

# Create radio buttons for resolutions
resolution_var = tk.StringVar(value="Phone Wallpaper")
for label, size in RESOLUTIONS.items():
    tk.Radiobutton(resolution_frame, text=label, variable=resolution_var, value=label).pack(anchor=tk.W)

# Create a frame for the resize option radio buttons
resize_option_frame = tk.LabelFrame(root, text="Resize Option", padx=10, pady=10)
resize_option_frame.pack(pady=10)

# Create radio buttons for resize options
resize_option_var = tk.StringVar(value="aspect_ratio")
tk.Radiobutton(resize_option_frame, text="Stretch", variable=resize_option_var, value="stretch").pack(anchor=tk.W)
tk.Radiobutton(resize_option_frame, text="Maintain Aspect Ratio", variable=resize_option_var, value="aspect_ratio").pack(anchor=tk.W)
tk.Radiobutton(resize_option_frame, text="Crop to Fit", variable=resize_option_var, value="crop").pack(anchor=tk.W)
tk.Radiobutton(resize_option_frame, text="Original Size", variable=resize_option_var, value="original").pack(anchor=tk.W)

# Create and pack the button to generate art
generate_button = tk.Button(root, text="Generate Pixel Art", command=generate_art, width=20)
generate_button.pack(pady=10)

# Start the GUI event loop
root.mainloop()
