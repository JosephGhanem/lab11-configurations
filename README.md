# Lab 11 · Configuration and Deployment Tools

This lab packages a console application that prints `Hello, World from Joseph_Ghanem!`.

## Debian x64

From the repository root on an amd64 Debian system with GCC and dpkg-deb:

```sh
./packaging/debian/build.sh
dpkg-deb --info dist/helloworld_Joseph_Ghanem.deb
sudo dpkg -i dist/helloworld_Joseph_Ghanem.deb
dpkg -l helloworld
helloworld
sudo dpkg -r helloworld
```

To compile and run only the C source, use `gcc -o helloworld src/helloworld.c` and then `./helloworld`. The DEB installs the executable in `/usr/local/bin` and the documentation in `/usr/share/doc/helloworld`. Its control file supplies the metadata used by dpkg.

## Windows x64

From the repository root on Debian with `g++-mingw-w64-x86-64` and `wixl`:

```sh
./packaging/windows/build.sh
```

The application is compiled from C++ with MinGW-w64. The installer is built from WiX XML with wixl. The main feature groups three components, one for each file installed under Program Files.

On Windows, open an elevated PowerShell prompt from the folder containing the MSI:

```powershell
msiexec.exe /i .\helloworld_Joseph_Ghanem.msi /qb
& "$env:ProgramFiles\HelloWorld\helloworld.exe"
```

Use Installed apps to view or remove **Hello World - Joseph Ghanem**. To compile only the C++ source on Windows, use `cl /EHsc src\helloworld.cpp` in a Visual Studio Developer Command Prompt and run `helloworld.exe`.
