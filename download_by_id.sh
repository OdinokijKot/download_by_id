#!/bin/bash
# Блок переменных
version="1.3"

max_request=600 	# Количество последовательных запросов к серверу
wait_time=120 		# Время перерыва в секундах
# В данный момент ограничение сервера 600 запросов в минуту ??

# Начальный и конечный ID релизов по умолчанию
start_id=1
end_id=10500

# Дельта для автоопределения начального и конечного ID
# Вычитается\добавляется к определённому начальному\конечному ID 
start_auto_delta=300
end_auto_delta=10

# Авторизация
authorization=0 		# Выполнять авторизацию (0\1)
user_name="" 	# Имя пользователя
password=""		# Пароль

cookie_file=".cookie" 	# Имя файла с куками для авторизации

# Рисовать ПрогрессБар (0\1)
ProgressBar_is_enable=1

# Настройка proxy-сервера
# Для работы через proxy-сервер введите его параметры в переменную proxy
# Подробно о синтаксисе написано тут https://curl.haxx.se/docs/manpage.html#-x
# Например:
#proxy="--proxy https://proxy-ssl.antizapret.prostovpn.org:3143"
# Для работы напрямую оставте эту переменную пустой или закомментируйте
#proxy=""

# Загрузка файла с внешними настройками
SCRIPTNAME=`readlink -e "$0"`
DIRECTORY=`dirname "$SCRIPTNAME"`

if [ -e $DIRECTORY/config.txt ]
  then
		echo "Файл настроек $DIRECTORY/config.txt загружен."
		source $DIRECTORY/config.txt
fi

# URL для скачивания релизов с авторизацией и без
url_auth_start="https://www.anilibria.tv/public/torrent/download.php?id="
url_auth_end=""
url_noauth_start="https://www.anilibria.tv/upload/torrents/"
url_noauth_end=".torrent"

# Параметры запуска curl
curl_params_post="${proxy} -fgLs -c ${cookie_file} -d mail=${user_name}&passwd=${password}&fa2code=&csrf=1 https://www.anilibria.tv/public/login.php"
curl_params_logout="${proxy} -fgLs -b ${cookie_file} https://www.anilibria.tv/public/logout.php"
curl_params_auth="${proxy} -fgLs -b ${cookie_file}"
curl_params_auth_filename="${proxy} -fgLsI -b ${cookie_file}"
curl_params_noauth="${proxy} -fgLsOJ"
curl_params_check="${proxy} -fgLsI"
curl_auto_end="${proxy} -fgLs -d query=list&page=1&perPage=1&filter=torrents https://www.anilibria.tv/public/api/index.php"

# Curl
curl_path=""
# Sleep
sleep_path=""
# Путь к стартовой директории
start_path=`pwd`

# Счётчики запросов
count=0
count_req=0
id=0
new_tor=0
del_tor=0

name=""
file_name=""

# Функция рисования ПрогрессБара
# Входные параметры текущее($1) начальное($2) конечное($3)
function ProgressBar {
	if [ x"${2}" = x"${3}" ] || [ "${2}" -gt "${3}" ] || [ "${1}" -lt "${2}" ] || [ "${1}" -gt "${3}" ]
	then return
	fi
	_columns=$(tput cols)
	let "_progress=((${1}-${2})*100/(${3}-${2})*100)/100"
	let "_done=(${_progress}*(${_columns}-32))/100"
	let "_left=${_columns}-32-$_done"
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")

	if [ "$1" -ne "$3" ]
		then 
			printf "\nВыполнено : [${_done// /#}${_left// /.}] ${_progress}%% id=${1}\e[F\e[K"
		else 
			printf "\nВыполнено : [${_done// /#}${_left// /.}] ${_progress}%% id=${1}\e[F\e[K\n\n"
	fi
}

# Начало основного скрипта
# Обработка входных параметров

if [ -z "$1" ] || [ -z "$2" ]
then
  echo "-----------------------------------------------------------------------------"
  echo "Скрипт для скачивания релизов по ID v ${version} (c) Odinokij_Kot"
  echo "Использование: `basename ${0}` функция каталог [начальный ID] [конечный ID]"
  echo
  echo "Функции: D или d - полная закачка;"
  echo "         S или s - синхронизация существующих релизов."
  echo
  echo "Начальный ID:"
  echo "         число   - явное задание значения ID;"
  echo "         A или a - автоматическое определение значения ID;"
  echo "         L или l - продолжить с последнего скачанного релиза."
  echo
  echo "Конечный ID:"
  echo "         число   - явное задание значения ID;"
  echo "         A или a - автоматическое определение значения ID."
  echo "Если начальный и конечный ID не указаны, они берутся из переменных сценария."
  echo "-----------------------------------------------------------------------------"
  exit 2
fi

# Проверка наличия curl
curl_path=`whereis -b curl | awk '{print $2}'`

if [ -z "$curl_path" ]
then
  echo "Утилита curl в системе не обнаружена. Установите её и попробуйте опять."
  exit 3
fi

# Проверка задания

# Проверка каталога
if [ ! -d "$2" ]
then
  echo "Каталог $2 отсутствует. Пытаемся его создать."
  mkdir -p $2
  if [ ! -d "$2" ]
  then
    echo "Не удалось создать каталог $2"
    exit 4
  fi
fi

cd $2

# Проверка конечного ID

if [ "$4" ]
then
  if [ x"$4" = xA ] || [ x"$4" = xa ] 
  then
  end_id=0
  
    IDs=$(${curl_path} ${curl_auto_end} | sed -e 's/[,{}]/\n/g' | sed -ne '/^\"url/p;' | sed -e 's/[^0-9]//g')

	if [ x"$IDs" = x ]
	then 
	  echo "Ошибка определения конечного ID"
	  exit 2
	fi

    for LINE in $IDs
    do
     if [ "$LINE" -gt "$end_id" ]
	 then
	    (( end_id=LINE ))
	 fi
    done
	
	(( end_id=end_id+end_auto_delta ))
	
  else
    (( end_id=$4 ))
  fi
  
  if [ "$end_id" -le 0 ]
  then 
    echo "Ошибка в указании конечного ID."
    exit 2
  fi
fi

# Проверка начального ID
if [ "$3" ]
then
	  start_id=0
	  if [ x"$3" = xA ] || [ x"$3" = xa ] 
	  then
			(( start_id=(end_id - start_auto_delta) ))
			if [ "$start_id" -le 0 ]
			  then (( start_id=1 ))
			fi
	  else
			if [ x"$3" = xL ] || [ x"$3" = xl ]
			then
				(( start_id=`ls -1 [0-9]*.torrent | sort -nrk1 -t "." | head -n1 | cut -d . -f 1`+1 ))
			else
				(( start_id=$3 ))
			fi
	  fi

	  if [ "$start_id" -le 0 ]
	  then 
		echo "Ошибка в указании начального ID."
		exit 2
	  fi
fi

if [ "$start_id" -gt "$end_id" ]
then 
  echo "Начальный ID больше конечного."
  exit 2
fi

# Проверка типа задания
if [ x"$1" != xD ] && [ x"$1" != xd ] && [ x"$1" != xs ] && [ x"$1" != xS ]
then
  echo "Неверно указана функция."
  exit 2
fi

# Проверка наличия sleep
sleep_path=`whereis -b sleep | awk '{print $2}'`

if [ -z "$sleep_path" ]
then
  echo "Утилита sleep в системе не обнаружена. Установите её и попробуйте опять."
  exit 3
fi

# Синхронизация релизов
if [ x"$1" = xs ] || [ x"$1" = xS ]
  then
    echo "Синхронизируем релизы."
    for file in *.torrent
    do
      echo "Проверяем $file"
      (( id=`echo "$file" | sed -e 's/\..*//'` ))
      ${curl_path} ${curl_params_check} ${url_noauth_start}${id}${url_noauth_end} > /dev/null
      if [ "$?" -eq 22 ]
      then
        mv -- "$file" "deleted.${file}.deleted"
        echo "Релиз $id не найден на трекере и переименован."
		let "del_tor += 1"
      fi
     done
	 echo "Релизов удалено: $del_tor."
fi

# Скачивание и синхронизация релизов
if [ x"$1" = xd ] || [ x"$1" = xD ]
then

echo "Качаем релизы с ${start_id} по ${end_id} ID."

case "$authorization" in

0 )
# Закачка релизов без авторизации
echo "Закачка без авторизации."

for ((count=start_id; count<=end_id; count++))
do

  if [ ! -e ${count}.*torrent ]
  then
    ${curl_path} ${curl_params_noauth} ${url_noauth_start}${count}${url_noauth_end}
    if [ "$?" -eq 0 ]
    then
      echo "Релиз $count скачан."
	  let "new_tor += 1"
    fi

  else
    ${curl_path} ${curl_params_check} ${url_noauth_start}${count}${url_noauth_end} > /dev/null
    if [ "$?" -eq 22 ]
    then
      mv -- ${count}.*torrent "deleted.${count}.torrent.deleted"
      echo "Релиз $count не найден на трекере и переименован."
	  let "del_tor += 1"
    fi

  fi

  if [ "$ProgressBar_is_enable" -eq 1 ]
  then ProgressBar ${count} ${start_id} ${end_id}
  fi

done
echo "Релизов скачано: $new_tor. Релизов удалено: $del_tor."
;;

1 )
# Закачка релизов c авторизацией
echo "Закачка с авторизацией."

# Авторизация на сервере

if [ "x`${curl_path} ${curl_params_post} | sed -e 's/{\"err\"\:\"//; s/\".*//g'`" != "xok" ]
then
  echo "Ошибка авторизации."
  exit 5
fi

for ((count=start_id; count<=end_id; count++))
do
  
  if [ "$count_req" -ge "$max_request" ]
    then
      echo "Пауза ${wait_time} секунд. Текущий ID ${count}."
	  if [ "$ProgressBar_is_enable" -eq 1 ]
	  then ProgressBar ${count} ${start_id} ${end_id}
	  fi
      ${sleep_path} ${wait_time}
      count_req=0
  fi

  name_tmp=`${curl_path} ${curl_params_auth_filename} ${url_auth_start}${count}${url_auth_end}`

  if [ "$?" -eq 22 ]
  then
      echo "Превышен лимит запросов. Пауза ${wait_time} секунд. Текущий ID ${count}."
	  if [ "$ProgressBar_is_enable" -eq 1 ]
	  then ProgressBar ${count} ${start_id} ${end_id}
	  fi
      ${sleep_path} ${wait_time}
      count_req=0
      name_tmp=`${curl_path} ${curl_params_auth_filename} ${url_auth_start}${count}${url_auth_end}`
      if [ "$?" -eq 22 ]
      then
        echo -e "\n\e[KОшибка обращения к сайту."
        exit 5
      fi
  fi

  name=`echo "$name_tmp" | grep -o -E 'filename=.*$' | sed -e 's/\"//g;s/filename=//;s/.$//'`

  let "count_req += 1"

  if [ ! -e ${count}.*torrent ]
  then
    if [ -n "$name" ]
    then
      ${curl_path} ${curl_params_auth} ${url_auth_start}${count}${url_auth_end} > ${count}
       if [ "$?" -eq 22 ]
       then
         echo "Превышен лимит запросов. Пауза ${wait_time} секунд. Текущий ID ${count}."
		 if [ "$ProgressBar_is_enable" -eq 1 ]
		 then ProgressBar ${count} ${start_id} ${end_id}
		 fi
         ${sleep_path} ${wait_time}
         count_req=0
         ${curl_path} ${curl_params_auth} ${url_auth_start}${count}${url_auth_end} > ${count}
         if [ "$?" -eq 22 ]
          then
            echo -e "\n\e[KОшибка обращения к сайту."
            exit 5
          fi
       fi

      let "count_req += 1"
      mv -- ${count} "${count}.${name}"
      echo "Релиз $count скачан."
	  let "new_tor += 1"
    fi
  else
    if [ -z "$name" ]
    then
      file_name=`find . -name "$count.*torrent" | sed -e 's/^\.\///'`
      mv -- "$file_name" "deleted.${file_name}.deleted"
      echo "Релиз $count не найден на трекере и переименован."
	  let "del_tor += 1"
    fi
  fi

  if [ "$ProgressBar_is_enable" -eq 1 ]
  then ProgressBar ${count} ${start_id} ${end_id}
  fi 

done
echo "Релизов скачано: $new_tor. Релизов удалено: $del_tor."
# LogOut на сайте
${curl_path} ${curl_params_logout} > /dev/null
rm "${cookie_file}"

;;
esac

fi

cd ${start_path}
echo "Готово."
exit 0