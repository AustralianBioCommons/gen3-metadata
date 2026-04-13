from setuptools import setup, find_packages

setup(
    name="gen3_metadata",  # Name of your package
    version="1.3.0",  # Version number
    packages=find_packages(where="src"),  # Automatically find packages in src/
    package_dir={"": "src"},  # Tell setuptools that packages are in src/
    install_requires=open("requirements.txt").read().splitlines(),  # Add dependencies from requirements.txt
    description="A library for downloading and manipulating gen3 metadata",
    author="Joshua Harris",
    author_email="harjo391@gmail.com",
    url="https://github.com/AustralianBioCommons/gen3-metadata",  # Optional: GitHub or project URL
)