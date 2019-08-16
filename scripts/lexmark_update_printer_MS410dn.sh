#!/bin/sh

# wrap in functions
# https://www.shellscript.sh/functions.html

get_password()
{
	# Check for the password
	# https://stackoverflow.com/questions/3061036/how-to-find-whether-or-not-a-variable-is-empty-in-bash
	if [ ${PRINTER_PASSWORD:+1} ]
	then
		printer_password="$PRINTER_PASSWORD"
		echo "Drucker Passwort ist gesetzt"
	else
	# https://stackoverflow.com/questions/3980668/how-to-get-a-password-from-a-shell-script-without-echoing
		stty -echo
		printf "Bitte geben sie das Drucker Passwort ein: "
		read printer_password
		stty echo
		printf "\n"
		printf "Dieses Skript versteht zur Automatisierung\n"
		printf "auch die Umgebungsvariable \$PRINTER_PASSWORD\n"
	fi
}

get_ip()
{
	# check for the target
	# https://stackoverflow.com/questions/3061036/how-to-find-whether-or-not-a-variable-is-empty-in-bash
	if [ ${PRINTER_IP:+1} ]
	then
		printer_ip="$PRINTER_IP"
		echo "Der Zieldrucker ist definiert."
	else
		printf "Bitte geben sie die Ziel IP ein: "
		read printer_ip
		printf "\n"
		printf "Dieses Skript versteht zur Automatisierung\n"
		printf "auch die Umgebungsvariable \$PRINTER_IP\n"
	fi
}

check_ip()
{
	# check prinmter connectivity
	if (ping -c 1 $printer_ip 2>&1 |/dev/null ) 
	then 
		echo "Der Drucker ist erreichbar."
	else
		echo "Der Drucker ist nicht erreichbar.\n Bitte versuchen sie es noch einmal." && return 1
	fi
}

get_firmware()
{

	# Check for the firmware file
	# https://stackoverflow.com/questions/3061036/how-to-find-whether-or-not-a-variable-is-empty-in-bash
	if [ ${PRINTER_FIRMWARE:+1} ]
	then
		printer_firmware="$PRINTER_FIRMWARE"
		echo "Die Firmware Datei wurde angegeben."
	else
		printf "Bitte geben sie den Pfad zur Firmware Datei relativ zu $PWD oder absolut an: "
		read printer_firmware
		printf "\n"
		printf "Dieses Skript versteht zur Automatisierung\n"
		printf "auch die Umgebungsvariable \$PRINTER_FIRMWARE\n"
	fi
}

check_firmware()
{
	# check if firmware is a file
	if [ -e "$printer_firmware" ]
	then 
		echo "Die Firmware Datei existiert."
	else
		echo "Die Firmware Datei $(printer_firmware) scheint nicht zu existieren.\n Bitte versuchen sie es noch einmal." && return 1
	fi
}

get_parameters()
{
	get_password
	get_ip
	check_ip
	return_ip=$?
	get_firmware
	check_firmware
	return_firmware=$?
	if [ "$return_ip" -eq "1" ]
	then
		return 11
	elif  [ "$return_firmware" -eq "1" ]
	then
		return 12
	else
		return 0
	fi
}

web_login()
{
# generate cookies
curl    \
	--include	\
	--data accid=54 \
	--data goto=/cgi-bin/dynamic/config/gen/code_update.html \
	--data login_type=password_only 	\
	--data password=$printer_password 	\
	--cookie cookie.txt 	\
	--cookie-jar cookie.txt 	\
	--location \
	http://$printer_ip/cgi-bin/posttest/printer/login.html	&& \
	(echo "Erfolgreich angemeldet."&& return 0) || \
	(echo "Es gab ein Problem mit der Anmeldung.\n Bitte versuchen sie es noch einmal" && return 1)
}

web_upload()
{
# upload firmware
curl 	\
	--cookie cookie.txt 	\
	--cookie-jar cookie.txt 	\
	--form upload=@"$printer_firmware"	\
	--form press=OK 	\
	--include 	\
	--location \
	http://$printer_ip/cgi-bin/postpf/cgi-bin/dynamicpf/pf/config/gen/code_update.html &&\
	(echo "Firmware erfolgreich hochgeladen." && return 0) || \
	(echo "Es gab ein Problem mit dem Firmware Upload.\n Bitte versuchen sie es noch einmal" && return 1)
}

web_get_version()
{
# upload firmware
curl 	\
	--cookie cookie.txt 	\
	--cookie-jar cookie.txt 	\
	--include 	\
	--location \
	http://$printer_ip/cgi-bin/dynamic/printer/config/reports/deviceinfo.html && return 0
}

###### MAIN SCRIPT
get_parameters
if [ "$?" -ne "0"]
then
	echo "Ein Fehler in den Parametern ist aufgetreten.\n Bitte versuchen sie es noch einmal" && exit 10
fi
web_login
if [ "$?" -ne "0"]
then
	echo "Ein Fehler beim Login ist aufgetreten.\n Bitte versuchen sie es noch einmal" && exit 20
fi
web_get_version

web_upload
if [ "$?" -ne "0"]
then
	echo "Ein Fehler beim Upload ist aufgetreten.\n Bitte versuchen sie es noch einmal" && exit 10
fi

# wait for printer to react
sleep 60
for i in 1 2 3 4 5 6 7 8 9 10
do
	sleep 60
	echo "Minute $(i) von 10"
	check_ip
	return_ip=$?
	if [ "$return_ip" -eq "0"]
	then
		continue
	fi
	echo "Warte noch eine Minute auf den Drucker\n"
done
web_get_version

exit 0

