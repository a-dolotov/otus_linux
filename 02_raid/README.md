# Занятие № 2   "Дисковая подсистема"



## Краткое содержание

Задачи дисковой системы. Программный и аппаратный RAID. RAID 0/1/5/6/10/60. Получение информации о дисковой системе системе с помощью dmidecode, dmesg, smartctl.
MBR и GPT. Команды gdisk/fdisk/parted/partprobe.

## Домашнее задание

Работа с mdadm.

добавить в Vagrantfile еще дисков
сломать/починить raid
собрать R0/R5/R10 на выбор
прописать собранный рейд в конф, чтобы рейд собирался при загрузке
создать GPT раздел и 5 партиций

в качестве проверки принимаются - измененный Vagrantfile, скрипт для создания рейда, конф для автосборки рейда при загрузке
\* доп. задание - Vagrantfile, который сразу собирает систему с подключенным рейдом
** перенесети работающую систему с одним диском на RAID 1. Даунтайм на загрузку с нового диска предполагается. В качестве проверики принимается вывод команды lsblk до и после и описание хода решения (можно воспользовать утилитой Script).

Критерии оценки: - 4 принято - сдан Vagrantfile и скрипт для сборки, который можно запустить на поднятом образе
\- 5 сделано доп задание

------



## Выполнение

Добавил в Vagrantfile еще дисков

```
:sata5 => {
                        :dfile => vb_machine_folder + '/' + vb_name + '/sata5.vdi',
                        :size => 250, # Megabytes
                        :port => 5
                },
:sata6 => {
                        :dfile => vb_machine_folder + '/' + vb_name + '/sata6.vdi',
                        :size => 250, # Megabytes
                        :port => 6
                },                       
```

Собрал массив RAID10, создал GPT раздел и 5 партиций

```
mdadm --create --verbose /dev/md0 -l 10 -n 6 /dev/sd{b,c,d,e,f,g} 
```

Создал файл mdadm.conf

```
mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf 
```

Создал GPT раздел и 5 партиций

    parted -s /dev/md0 mklabel gpt
    parted /dev/md0 mkpart primary ext4 0% 20%
    parted /dev/md0 mkpart primary ext4 20% 40%
    parted /dev/md0 mkpart primary ext4 40% 60%
    parted /dev/md0 mkpart primary ext4 60% 80%
    parted /dev/md0 mkpart primary ext4 80% 100%
    for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
    mkdir -p /raid/part{1,2,3,4,5}
    for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i | echo "/dev/md0p$i \
    /raid/part$i ext4 defaults 0 0" >> /etc/fstab ; done

Провел различные манипуляции с массивом (сломал, починил)

```
mdadm /dev/md0 --fail /dev/sdd
mdadm /dev/md0 --remove /dev/sdd
mdadm /dev/md0 --add /dev/sdd
```

Мониторил состояние массива:

```
cat /proc/mdstat
mdadm -D /dev/md0
```

- *Приложен Vagrantfile, который сразу собирает систему с подключенным рейдом  

каталог 01_raid/raid_10)

- **



