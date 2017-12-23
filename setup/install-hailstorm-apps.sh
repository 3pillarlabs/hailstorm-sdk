#!/usr/bin/env bash

# install hailstorm apps if they have been modified

sudo -i

install_path=/usr/local/lib

# install hailstorm-gem hailstorm-redis
for app in hailstorm-gem hailstorm-redis hailstorm-web; do
	app_sha1=`find /vagrant/$app ! -path '*.git' -type f -exec cat {} + | sha1sum | cut -f1 -d' '`
	install_app='no'
	if [ ! -e $install_path/$app.sha1 ]; then
		install_app='yes'
	else
		app_last_sha1=`cat $install_path/$app.sha1`
		if [ "$app_last_sha1" != "$app_sha1" ]; then
			install_app='yes'
		fi
	fi

	if [ $install_app = 'yes' ]; then
		rm -rf $install_path/$app
		cp -r /vagrant/$app $install_path/
		echo $app_sha1 > $install_path/$app.sha1
		echo "Installed $app"
	fi
done

exit
