from PIL import Image
import os

def generate_icons():
	source_path = os.path.join(os.getcwd(), 'assets', 'App_icon.png')
	if not os.path.exists(source_path):
		print(f"Source icon not found at: {source_path}")
		return

	sizes = {
		'mdpi': 48,
		'hdpi': 72,
		'xhdpi': 96,
		'xxhdpi': 144,
		'xxxhdpi': 192
	}

	try:
		source_image = Image.open(source_path)
		for density, size in sizes.items():
			target_dir = os.path.join(os.getcwd(), 'android', 'app', 'src', 'main', 'res', f'mipmap-{density}')
			target_path = os.path.join(target_dir, 'ic_launcher.png')
			
			# Ensure target directory exists
			os.makedirs(target_dir, exist_ok=True)
			
			# Resize and save
			resized = source_image.resize((size, size), Image.Resampling.LANCZOS)
			resized.save(target_path, 'PNG', optimize=True)
			print(f"Generated icon for {density}: {target_path}")

	except Exception as e:
		print(f"Error processing image: {e}")

if __name__ == '__main__':
	generate_icons()