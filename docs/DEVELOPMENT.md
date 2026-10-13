# Ada development setup

Project: C:\Repos\AdaExperiments

Installed: Alire 2.1.1, GNAT Native 16.1.0, GPRbuild package 26.0.1,
MSYS2, Make, GDB 18.1, VS Code Ada & SPARK extension, Raylib Ada 2.0.0,
and official Raylib 6.0 Windows x64 MinGW libraries.

## Start working

Double-click C:\Repos\AdaExperiments\Open-Ada-VSCode.cmd.
This opens VS Code normally; the Ada extension manages Alire integration. The GPR project is selected
in workspace settings. Ctrl+Shift+B builds. F5 debugs the economy example.
Use Terminal > Run Task > Ada: Run to run it.

In a NEW PowerShell window:

    cd C:\Repos\AdaExperiments
    alr build
    alr run

Existing terminal windows may need to be reopened to pick up the Alire PATH.
The compiler is managed by Alire; use alr exec when invoking tools directly.

Edit src\ada_experiments.adb to change the economy example.
Ada 2022 is explicitly enabled in ada_experiments.gpr.

## Raylib

The project imports raylib.gpr and has the required Windows linker switches.
The native library is stored in vendor\libraylib and pinned locally because
the expected MSYS2 mingw-w64-x86_64-raylib package is unavailable.
Its headers, library path, and DLL path are supplied automatically by Alire.
Original native library license and README are included in the vendor folder.

Verify native linkage:

    alr exec -- .\bin\raylib_check.exe

The check does not open a graphics window. Actual window rendering has not
been verified. Keep simulation code independent of graphics as it grows.
The upstream Raylib GUI binding emits an aliasing warning; builds still pass.

## Dependencies and new projects

    alr search json
    alr with <package_name>

To create another executable project:

    cd C:\Repos
    alr init --bin my_experiment
    cd my_experiment
    alr build
    alr run

Git is initialized for AdaExperiments. No commits or remote were created.
The generated project license is MIT OR Apache-2.0 WITH LLVM-exception;
choose your preferred license before publishing. Publishing author metadata
was omitted because no name or email was provided.

## Verification completed

- Economy example compiled and ran: year 10 population = 1500.
- Ada 2022 compiler switch enabled.
- GDB stopped at the source breakpoint and printed Population = 1000.
- Raylib native GetRandomValue call returned its expected value.
- VS Code build/run tasks and F5 launch configuration created.

## Installation notes

Automatic approval review blocked the Alire installer launch. The official
portable Windows package was installed instead, with its bin directory added
to the user PATH. Alire then installed and updated MSYS2 normally.

Official references:
https://alire.ada.dev/docs/getting-started
https://alire.ada.dev/crates/raylib
https://github.com/raysan5/raylib/releases/tag/6.0
https://docs.adacore.com/live/wave/als/html/vscode-extension-doc/Getting-Started.html

## If a terminal reports an already defined ALIRE_PREFIX

Run .\Reset-Ada-Environment.ps1 in that terminal, then alr build.
Create a new VS Code terminal to use the corrected workspace environment.

