# download_by_id
Скрипт для массового скачивания torrent-раздач сайта [AniLibria.tv](https://www.anilibria.tv)  
Все торрент-файлы на сайте имеют свой собственный идентификатор. Данный идентификатор не повторяется и линейно растёт при обновлении раздачи на сайте.    

# Запуск
./download_by_id.sh _функция_ _каталог_ \[начальный ID\] \[конечный ID\]  

## Функции  

	D или d - полная закачка;
	S или s - синхронизация существующих релизов.

## Каталог  
имя каталога, в котором сохраняются torrent-файлы.  

## Начальный ID  
идентификатор, с которого начинается проверка раздач на сайте. 
Возможные значения:  

	число   - явное задание значения ID;
	A или a - автоматическое определение значения ID;
	L или l - продолжить с последнего скачанного релиза.

## Конечный ID  
идентификатор, которым оканчивается проверка раздач на сайте. 
Возможные значения: 

	число   - явное задание значения ID;
	A или a - автоматическое определение значения ID.
		
Если начальный и конечный ID не указаны, они берутся из переменных "start_id" и "end_id" скрипта.

# Настройки  
В начале скрипта присутствуют переменные настроек. Данные настройки можно вписать как непосредственно в файл скрипта, так и в файл конфигурации "config.txt". Файл конфигурации должен быть сохранён в каталоге с torrent-файлами.

## Настройки авторизации  
Скрипт может скачивать torrent-файлы как с авторизацией, так и без неё.  
Для включения авторизации необходимо изменить на "1" параметр "authorization" и вписать свои имя пользователя и пароль.  
Пример:

	authorization=1
	user_name="anilibria_fan"
	password="12345"

## Настройки PROXY  
Для работы через proxy-сервер введите его параметры в переменную "proxy"  
Подробно о синтаксисе написано [тут](https://curl.haxx.se/docs/manpage.html#-x)  
Например:  

	proxy="--proxy https://proxy-ssl.antizapret.prostovpn.org:3143"
	
Для работы напрямую оставте эту переменную пустой или закомментируйте.
