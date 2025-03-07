#!/bin/bash

distro=`lsb_release -is`
release=`lsb_release -rs`

if [[ $distro == "Ubuntu" ]]; then # replace 8.04 by the number of release you want

		if [[ $release == "24.10" || $release == "24.04" ]]; then # replace 8.04 by the number of release you want
			echo "Downloading CoppeliaSim"
			wget https://downloads.coppeliarobotics.com/V4_9_0_rev6/CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu24_04.tar.xz
			tar -xJf CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu24_04.tar.xz
			mv CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu24_04 CoppeliaSim_Edu_Ubuntu
			rm CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu24_04.tar.xz
			cd ../../
		elif [[ $release == "22.10" || $release == "22.04" ]]; then # replace 8.04 by the number of release you want
			echo "Downloading CoppeliaSim"
			wget https://downloads.coppeliarobotics.com/V4_9_0_rev6/CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu22_04.tar.xz
			tar -xJf CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu22_04.tar.xz
			mv CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu22_04 CoppeliaSim_Edu_Ubuntu
			rm CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu22_04.tar.xz
			cd ../../
		elif [[ $release == "20.10" || $release == "20.04" ]]; then # replace 8.04 by the number of release you want
			echo "Downloading CoppeliaSim"
			wget https://downloads.coppeliarobotics.com/V4_9_0_rev6/CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu20_04.tar.xz
			tar -xJf CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu20_04.tar.xz
			mv CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu20_04 CoppeliaSim_Edu_Ubuntu
			rm CoppeliaSim_Edu_V4_9_0_rev6_Ubuntu20_04.tar.xz
			cd ../../
		# elif [[ $release == "18.10" || r$elease == "18.04" ]]; then # replace 8.04 by the number of release you want
		# 	echo "Downloading CoppeliaSim"
		# 	wget https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz
		# 	tar -xJf CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz
		# 	mv CoppeliaSim_Edu_V4_1_0_Ubuntu18_04 CoppeliaSim_Edu_Ubuntu
		# 	rm CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz
		# 	cd ../../
		# elif [[ $release == "16.04" || $release == "16.10" ]]; then
		# 	echo "Downloading CoppeliaSim"
		# 	wget https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu16_04.tar.xz
		# 	tar -xJf CoppeliaSim_Edu_V4_1_0_Ubuntu16_04.tar.xz
		# 	mv CoppeliaSim_Edu_V4_1_0_Ubuntu16_04 CoppeliaSim_Edu_Ubuntu
		# 	rm CoppeliaSim_Edu_V4_1_0_Ubuntu16_04.tar.xz
		# 	cd ../../
		else 
			echo "Non-compatible release. Only supported Ubuntu 20.04 +."
		fi
else 
		echo "Non-compatible version. Only supported Ubuntu 20.04 +."
fi
