from PIL import Image, ImageDraw, ImageFont

# 1. Base Setup (macOS Big Sur Style Squircle)
size = (1024, 1024)
bg_color = (30, 32, 35) # Dark Gray Background
accent_color = (80, 220, 100) # Sangtae Green

img = Image.new('RGB', size, color=bg_color)
draw = ImageDraw.Draw(img)

# 2. Draw 'Chevron Up' Motif (Matches SF Symbol 'chevron.up')
# Center X: 512
# Top Point: (512, 280)
# Bottom Left: (200, 650)
# Bottom Right: (824, 650)
# Stroke Width: 140
# Style: Rounded Joins/Caps

# Coordinates for thick line drawing
# We'll simulate a thick stroke by drawing a polygon or using line with width

line_width = 140

# Points for the chevron
# Left leg: (200, 650) -> (512, 280)
# Right leg: (512, 280) -> (824, 650)

# Draw lines with rounded ends
draw.line([(200, 650), (512, 280), (824, 650)], fill=accent_color, width=line_width, joint="curve")

# Manually add rounded caps at the bottom ends if needed, but PIL's line usually handles it reasonably well for icons.
# Let's ensure the ends are rounded by drawing circles at endpoints
r = line_width / 2
draw.ellipse((200-r, 650-r, 200+r, 650+r), fill=accent_color)
draw.ellipse((824-r, 650-r, 824+r, 650+r), fill=accent_color)
# The top join is handled by 'joint="curve"' (or we can draw a circle there too to be safe)
draw.ellipse((512-r, 280-r, 512+r, 280+r), fill=accent_color)

# Save
img.save("AppIcon.png")
print("Generated 'Chevron Up' icon.")
