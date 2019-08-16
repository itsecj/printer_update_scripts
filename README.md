# printer_update_scripts
A set of scripts and and probably ansible task to update printer firmware

# design principles:
- everything should be replaceble by environment variables for the scripts
- the ansible roles should check for the same environment variables
- environment variables take precendence
- all user interactive elements in ansible tasks are tagged `user_interactive`, so they can be skipped
