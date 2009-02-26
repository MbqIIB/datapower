
This directory contains an exported domain for the datapower
box. To load the domain into a datapower box:

1) Make sure you do not have an existing domain called
Nces - that is the name of the domain contained in this
zip file.

2) Log into the datapower web console using the default
domain.

3) Select the import configuration icon at the bottom
of the screen. Make sure the 'zip' option is selected
(it's the default) and browse to your zip file.
Hit next.

4) Select the Nces domain checkbox and hit next.

5) Don't change anything on the 'Import Configuration'
screen - just select Import.

6) On the next screen hit Done.

7) Your domain is now imported, but the datapower will
not import certs or keys, so go back to the control
panel (Hit the menu item, upper left) and select
"Keys & Certs Management" icon, lower right.

8) Select SSL/Crypto Profile.

9) Select the service-discovery profile.

10) Select the '...' button next to the identification
credentials and re-upload the key and cert for this
datapower box.

11) Repeat this for the Validation credentials - these
are the certs that this datapowerbox trusts.

12) Don't forget to save the domain configuration,
link at the very top  right: 'Save Config'.
or keys, so you
