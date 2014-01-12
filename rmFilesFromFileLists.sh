#!/bin/sh
#==============================================================================
# Name
# 		rmFilesFromFileLists.sh - remove files from the fileList.
# Syntax
# 		rmFilesFromFileLists.sh fileList [PARTITION_LINE PROCESS_COUNT]
# Description
# 		remove file from the fileList, It supports multiple  and the sub-process has the specified workload.
# 		It's succeed at HP Unix Server and Linux Server[CentOS] 
#		Options:
#			fileList  - mandatory - the file what stores the files that is to be removed.
#			PARTITION_LINE 	- Optional - Default:1200 - the workload that every sub-process needs to do.
#			PROCESS_COUNT	- Optional - Default:4	- the count of the sub-processes.
#		Usages:
#			rmFilesFromFileLists.sh fileList
#			rmFilesFromFileLists.sh fileList PARTITION_LINE
#			rmFilesFromFileLists.sh fileList PARTITION_LINE PROCESS_COUNT
# Author
# 		April Lee
# Statements
#		If you have any questions, please do NOT disturb me[April Lee] before you did NOT do anything. 
#		Thank you for your understanding.	
# ChangeLog:
#		Version		|	modifier	|	Revised									|	description	
# 		1.0			|	April Lee	|	Initial 
#		2.0			|	April Lee	| 	Improved the performance
# 		3.0			|	April Lee	|	Trace the execution progress.
#===========================================================================================================
ORIGINAL_FILE=${1}

#Const variables
PARTITION_LINE=1200 # default partition lines
FAILED_RM_LOG=$PWD"/failed_to_rm_file_list.$$.log"
EXECTION_LOG=$PWD"/excution_rm_file_list_log.$$.log"
PROCESS_COUNT=4 # default count of sub-process
TOTAL_LINES=0 # init  total lines 
VERSION=3.0

# multiple threads
mt_tmp_fifo=$PWD"/$$.fifo"
mkfifo $mt_tmp_fifo
exec 6<>$mt_tmp_fifo  # about file descriptor please `ls /proc/self/fd`
rm $mt_tmp_fifo

threadCounter=0
while [[ $threadCounter -lt $PROCESS_COUNT ]]; do
    threadCounter=`expr $threadCounter + 1`
    echo >&6
done

function title_menu {
    echo "================================================"
    echo "remove the files in the specified file"
    echo "Author: April Lee"
    echo "Version: $VERSION"
    echo "Copyright@Informatica Support Team"
    echo "================================================"
}

function usage_menu {
    echo "Usages:"
    echo "     `basename $0` fileList"
	echo "     `basename $0` fileList PARTITION_LINE"
	echo "     `basename $0` fileList PARTITION_LINE PROCESS_COUNT"
}

# check the progress 
# $1: total
# $2: have finished
# $3: the EXECTION_LOG log file
function check_progress {
	if [ $# -eq 1 ]; then
		echo "Until `date +[%Y-%m-%d]%H:%M:%S`, the progress is $1%" | tee -a $3
	else
		progress=`echo "scale=2;$2 * 100 / $1"|bc` 
		echo "Until `date +[%Y-%m-%d]%H:%M:%S`, the progress is $progress%" | tee -a $3
	fi
}


# del_robot function is just like a robot to remove files, if failed, the 
# log the file into the log file.
# $1: left lines
# $2: the lines is going to be removed 
# $3: the log file that's used to log the file which is failed to remove;
# In a word, delete the lines from ($1) to ($1+$2)
function del_robot {
    cat $ORIGINAL_FILE | tail -n $1 | head -n $2 | while read ALine
    do
        # echo "del_robot:   $ALine"
		# if [ -f $ALine ]; then
		rm -f $ALine || {
			echo "$ALine" | tee -a ${3}
		} 
        # fi
    done
}

function del_robot_not_perfect {
    head -n $1 $ORIGINAL_FILE | while read ALine
    do
        # echo "del_robot_not_perfect:   $ALine"
		# if [ -f $ALine ]; then
		rm -f $ALine || {
			echo "$ALine" | tee -a ${2}
		}
		# fi
    done
}

# robot_manager function is a manager who manages the del_robot
# $1: total lines
# $2: the partition line numbers
# $3: the log file that's used to log the file which is failed to remove;
# $4: the log file that's used to log the execution information
function robot_manager {
    SEGMENT=`expr $1 / $2`
    NOT_PERFECT=`expr $1 % $2`
    
	if [ $NOT_PERFECT -gt 0 ]; then
		{
			del_robot_not_perfect $NOT_PERFECT $3
		}&
    fi

    segCounter=1
    while [[ $segCounter -le $SEGMENT ]]; do
        read -u6
       {
            LEFT_LINES=`expr $2 \* $segCounter`
            del_robot $LEFT_LINES $2 $3
			check_progress $SEGMENT $segCounter $4
			echo >&6
       }&  
	   
	   segCounter=`expr $segCounter + 1`
    done
}

function check_variable {
    if [ $# -lt 1 ]; then
    	echo -e "\a"
        echo "Error: the count of arguments must be greater than 1"
        usage_menu
        exit 1;
    fi
	
    if [ ! -f $ORIGINAL_FILE ]; then
    	echo -e "\a"
        echo "Error: $ORIGINAL_FILE does not  exsit"
        usage_menu
        exit 1;
    fi;
    
    TOTAL_LINES=`wc -l $ORIGINAL_FILE | cut -d ' ' -f 1`
    
    if [ $TOTAL_LINES -eq 0 ]; then
    	echo -e "\a"
        echo "Warning: $ORIGINAL_FILE does not have any contents "
        usage_menu
        exit 1;
    fi
	
	if [[ $# -eq 2 && $2 -gt 0 ]]; then
		PARTITION_LINE=$2
	elif [[ $# -eq 3  && $2 -gt 0 && $3 -gt 0 ]]; then
		PARTITION_LINE=$2
		PROCESS_COUNT=$3
    else
        echo "The argument $2 or $3 is/are not right, it will use the default"
	fi

    echo "----------------LIST---------------------------"
    echo "FileList is: $ORIGINAL_FILE"
    echo "PARTITION_LINE is: $PARTITION_LINE"
    echo "PROCESS_COUNT is: $PROCESS_COUNT"
    echo "Is it right?[Y/N]"
    read GOON
    if [ $GOON != 'Y' ];then
        exit 1
    fi
}


# show title
title_menu

check_variable $*

echo `date +"%Y-%m-%d %H:%M:%S"` | tee -a $EXECTION_LOG
echo "Ready, Go!" | tee -a $EXECTION_LOG
echo "Please kindly waiting..." | tee -a $EXECTION_LOG

# call manager to invoke the del_robot to rm the files
robot_manager $TOTAL_LINES $PARTITION_LINE $FAILED_RM_LOG $EXECTION_LOG

wait
exec 6>&-
echo "Congratulations!!! the task is over!" | tee -a $EXECTION_LOG
echo `date +"%Y-%m-%d %H:%M:%S"` | tee -a $EXECTION_LOG
exit 0
