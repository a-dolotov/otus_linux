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

#### Сборка рэйда 

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



#### *Сборка рэйда при загрузке

Приложен Vagrantfile, который сразу собирает систему с подключенным рейдом  

https://github.com/a-dolotov/otus_linux/tree/master/02_raid/raid_10



#### ** Перенос работающей системы с одним диском на RAID 1

Добавил диск равного размера. 

Вывод `lsblk` в первоначальном состоянии

```
[root@otuslinux ~]# lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk 
└─sda1   8:1    0  40G  0 part /
sdb      8:16   0  40G  0 disk 
```

Скопирова таблицу разделов диска `/dev/sda` на диск `/dev/sdb`:

```
sfdisk -d /dev/sda | sfdisk /dev/sdb
```

Изменил тип нового  диска `/dev/sdb` на «Linux raid autodetect» 

```
fdisk /dev/sdb 
t
fd
w
```

Создал массив, указав один из дисков массива как отсутствующий:

```
mdadm --create /dev/md0 --metadata=0.90 --level=1 --raid-devices=2 missing /dev/sdb1
```

Создал файловую систему

```
mkfs.xfs /dev/md0
```

Создал конфиг для mdadm

```
mkdir /etc/mdadm
mdadm --detail --scan > /etc/mdadm/mdadm.conf
```

Отключил SELinux в `/etc/selinux/config`, иначе после загрузки с raid не получится залогиниться в систему (подсказка преподавателя)

```
SELINUX=disabled
```



Смонтировал массив

```
mount /dev/md0 /mnt/
```

Скопировал систему на массив

```
rsync -axu / /mnt/
```

Смонтировал информацию о текущей системе в  новый корень и chroot в него

```
mount --bind /proc /mnt/proc && mount --bind /dev /mnt/dev && mount --bind /sys /mnt/sys \ && mount --bind /run /mnt/run && chroot /mnt/
```

Скорректировал /etc/fstab, прописал UUID массива. Чтобы добавить UUID и затем подправить выполнил:

```
ls -l /dev/disk/by-uuid |grep md >> /etc/fstab && vi /etc/fstab
```

Обновил initramfs, с нужными модулями

```
mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.$(date +%m-%d-%H%M%S).bak
dracut /boot/initramfs-$(uname -r).img $(uname -r)
```

Подправил `/etc/default/grub` добавил параметр «`rd.auto=1`» в строку «`GRUB_CMDLINE_LINUX`»

Перписал конфиг GRUB и установил его на диск `/dev/sdb`

```
grub2-mkconfig -o /boot/grub2/grub.cfg 
grub2-install /dev/sdb
```

Перезагрузка

После перезагрузки выбрал загрузку со второго диска

Изменил тип первого  диска `/dev/sda` на «Linux raid autodetect» 

```
fdisk /dev/sda
t
fd
w
```

Добавил первый диск в массив

```
mdadm /dev/md0 --add /dev/sda1
```

Наблюдал за состоянием массива

```
mdadm -D /dev/md0
cat /proc/mdstat 
```

Переустановил GRUB на первый диск

```
grub2-install /dev/sda
```

Вывод `lsblk` в первоначальном состоянии

```
[root@otuslinux ~]# lsblk
NAME    MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
sda       8:0    0  40G  0 disk  
└─sda1    8:1    0  40G  0 part  
  └─md0   9:0    0  40G  0 raid1 /
sdb       8:16   0  40G  0 disk  
└─sdb1    8:17   0  40G  0 part  
  └─md0   9:0    0  40G  0 raid1 /
```

Поочередно извлекал первый и второй диски - система загружалась