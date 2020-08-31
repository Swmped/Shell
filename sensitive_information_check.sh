#!/bin/bash
#set -e
stty erase ^H

#获取脚本所在的目录
base_path=$(cd `dirname $0` && pwd)
#源码存放目录
source_code_path=$1
#扫描结果输出目录
result_path="${base_path}/Sensitive_Information_Check_Result"


#主菜单
menu(){
	clear
	echo -e "\t\t\t敏感信息检索脚本"
	echo -e "0. 解压压缩文件"
	echo -e "1. 中文检索"
	echo -e "2. 个人信息检索[手机号/身份证号/邮箱]"
	echo -e "3. 特定格式文件收集[csv/xls/doc/ppt/sql/jpg等]"
	echo -e "4. 自定义关键词检索"
	echo -e "5. IP检索"
	echo -e "6. 查看检索结果"
	echo -e "7. 结束"
}

#查看结果菜单
results_menu(){
	clear
	echo -e "1. 查看中文检索结果"
	echo -e "2. 查看个人信息检索结果"
	echo -e "3. 查看特定格式文件收集结果"
	echo -e "4. 查看自定义关键词检索结果"
	echo -e "5. 查看IP检索结果"
	echo -e "6. 返回上一级菜单"
	echo -e "7. 结束"
}

#判断目录是否存在
dir_exists(){
	if [ ! -d $1 ];then
		echo "Error: 目录'$1'不存在!"
		exit 1
	fi
}

#压缩包解压
decompress(){
	#压缩文件名,如/root/test.zip
	file_name=$1
	#压缩文件后缀名
	format=$2
	#file_path=`echo $file_name | awk 'BEGIN{FS="/";OFS="/"}{$NF="";print}'`
	file_path=${file_name%.*}_decompressed
	if [ ! -d ${file_path} ];then
		mkdir -p ${file_path}
	fi
	case ${format} in
	zip|jar|war)
		unzip ${file_name} -d ${file_path}
		;;
	rar)
		unrar x ${file_name} ${file_path}
		;;
	7z)
		7z x ${file_name} ${file_path}
		;;
	tar)
		tar -xf ${file_name} -C ${file_path} >/dev/null 2>&1
		;;
	tgz|tar.gz)
		tar -zxf ${file_name} -C ${file_path} >/dev/null 2>&1
		;;
	tar.bz2)
		tar -jxf ${file_name} -C ${file_path}
		;;
	*)
		echo "  未知的压缩格式:${format}"
		;;
	esac
}

#特定格式文件收集
files_collect(){
	#源码存放目录
	directory=$1
	#要收集的文件格式
	file_types="md csv xls xlsx pdf doc docx ppt pptx db sql jpg jpeg png bmp gif"
	#特定格式文件存放目录
	file_storage_path=${result_path}/files
	if [ ! -d ${file_storage_path} ];then
		mkdir -p ${file_storage_path}
	fi
	echo -e "  特定格式文件收集中......\c"
	for file_type in ${file_types}
	do
		files=`find ${directory} -name *.${file_type}`
	        if [ -z "${files}" ];then
        	        continue
	        else
        	        mkdir -p ${file_storage_path}/${file_type}
	        fi
        	for file in ${files}
	        do
        	        cp ${file} ${file_storage_path}/${file_type}
	        done
	done
	echo -e "完成\n"
}

#grep检索信息
detect(){
	#grep option,若无则使用""
	option=$1
	#grep pattern
	pattern=$2
	#grep 检索目录即源码存放目录
	directory=$3
	#检索结果保存文件
	result_file=$4
	#说明
	title=$5
	
	echo -e "  ${title}......\c"
	grep ${option} ${pattern} ${directory} > ${result_path}/${result_file}
	sed -i '/Binary file/d' ${result_path}/${result_file}
	awk 'BEGIN{FS=":"}{print $1}' ${result_path}/${result_file} | uniq -c | sort -k 1 -n -r > ${result_path}/${result_file}_stat
	echo -e "完成\n"
}

#检索结果显示
result_display(){
	#检索结果保存文件
	result_file=$1
        read -p "  输入n,查看匹配行数超过n行的文件：" line
	if ! expr ${line} + 0 &> /dev/null; then
        	echo -e "\n  输入错误！\n"
                continue
        fi
        #统计满足条件的文件总数
        sum=`awk -v var1=${line} '{if($1 >= var1) print $2}' ${result_path}/${result_file}_stat | wc -l`
        array_lines=()
        array_files=()
        i=1
        while [ ${i} -le ${sum} ]
        do
                array_lines[$i]=`awk -v var2=$i 'NR==var2{print $1}' ${result_path}/${result_file}_stat`
                array_files[$i]=`awk -v var2=$i 'NR==var2{print $2}' ${result_path}/${result_file}_stat`
                i=$[ $i + 1 ]
        done
	#格式化输出
        i=1
        echo -e "|  序号\t|   匹配行数    |\t\t\t\t文件"
        while [ ${i} -le ${sum} ]
        do
                echo -e "|  ${i}\t|\t${array_lines[$i]}\t|  ${array_files[$i]}"   
                i=$[ $i + 1 ]
        done
        #查看文件中的详细中文内容
        while [ 1 ]
        do
                read -p "  按'r'返回菜单 or 输入序号查看文件详细内容：" file_sn
		if [ "${file_sn}" = "r" ];then
			break
		fi
                if expr ${file_sn} + 0 &> /dev/null; then
                        if [[ ${file_sn} -le 0 || ${file_sn} -gt ${sum} ]]; then
                                echo -e "\n  输入错误！\n"
                                continue
                        fi
                else
                        echo -e "\n  输入错误！\n"
                        continue
                fi
                less ${array_files[$file_sn]}
        done
}


#######################################################################################################################


dir_exists ${source_code_path}
if [ -d ${result_path} ];then
	rm -rf ${result_path}
	mkdir -p ${result_path}
else
	mkdir -p ${result_path}
fi
menu
while [ 1 ]
do
	read -p "输入序号:" menu_sn
	case ${menu_sn} in
	0)
		#解压压缩包
		#zip/rar/7z/tar/tar.gz/jar/war
		compressed_formats="zip rar 7z tar tar.gz tgz tar.bz2 jar war"
		for format in ${compressed_formats}
		do
			compressed_files=`find ${source_code_path} -name *.${format}`
			if [ -z "${compressed_files}" ];then
				continue
			fi
			for file_name in ${compressed_files}
			do
				echo -e "  发现${file_name}\t\t\c"
				decompress ${file_name} ${format}
				if [ $? -e 0 ];then
					echo "解压完成"
				else
					echo "解压失败"
				fi
			done
		done
		;;
	1)
		#中文检索
		chinese_regex="[^\x4e\x00-\x9f\xff]"
		detect "-r -n -P" "${chinese_regex}" "${source_code_path}" "Chinese" "中文检索"
		;;
	2)
		#个人信息检索--手机号&身份证&邮箱
		personal_information_regex="(13[0-9]|14[5|7]|15[0|1|2|3|4|5|6|7|8|9]|18[0|1|2|3|5|6|7|8|9])\d{8}|(\d{18})|(\d{17}(\d|X|x))|\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*"
		detect "-r -n -P" "${personal_information_regex}" "${source_code_path}" "Personal_Information" "个人信息检索"
		;;
	3)
		#特定格式文件收集
		files_collect "${source_code_path}"
		;;
	4)
		#关键字检索
		read -p '  输入一个或多个关键词,以"|"分隔:' keywords
		keywords_regex=$(echo "${keywords}" | tr -d "[:space:]")
		detect "-r -n -E" "${keywords_regex}" "${source_code_path}" "Keywords" "关键字检索"
		;;
	5)
		#IP检索
		ip_regex="[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
		detect "-r -n -e" "${ip_regex}" "${source_code_path}" "IP" "IP检索"
		;;
	6)
		while [ 1 ]
		do
			results_menu
		        read -p "输入序号:" result_sn
			case ${result_sn} in
			1)
				result_display Chinese
				;;
			2)
				result_display Personal_Information
				;;
			3)
				echo -e "  收集的文件存放在${result_path}\n"
				sleep 5
				;;
			4)
				result_display Keywords
				;;
			5)
				result_display IP
				;;
			6)
				menu
				break
				;;
			7)
				exit 0
				;;
			*)
				echo -e "\n输入错误！\n"
				;;
			esac
		done
		;;
	7)
		exit 0
		;;
	*)
		echo -e "\n输入错误！\n"
		;;
	esac
done
