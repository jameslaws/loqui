# What to try: Windows groundwork

Step 1 of Loqui for Windows. Nothing to install yet: these were checked on GitHub's Windows computers, and the pictures come from them. Dictation arrives in step 2.

## What to do
Open the latest Windows check run and look at the picture from the Intel/AMD Windows computer.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml
See: loqui's microphone icon by the clock with its menu open ("loqui is running", "About loqui", "Quit loqui"), and the About window showing the version.
Shots: built/winbase-01-x64-menu-and-about.png
Checks: WINBASE-01

## What to do
Look at the same picture from the Arm Windows computer.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml
See: the same menu and About window on Windows 11 for Arm.
Shots: built/winbase-02-arm-menu-and-about.png
Checks: WINBASE-02

## What to do
Look at the pictures taken three seconds after choosing Quit loqui.
Where: https://github.com/jameslaws/loqui/actions/workflows/windows.yml
See: the icon is gone from beside the clock on both computers, and nothing of loqui is left running.
Shots: built/winbase-03-x64-after-quit.png, built/winbase-03-arm-after-quit.png
Checks: WINBASE-03

## What to do
Open the Mac check and the two Windows checks on the latest run and compare the cleanup examples.
Where: https://github.com/jameslaws/loqui/actions
See: all three list the same cleanup examples by name, every one passed, so the Mac and Windows clean up your words the same way.
Checks: CLEAN-01, CLEAN-02, CLEAN-03
