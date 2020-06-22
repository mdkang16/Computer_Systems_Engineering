
.data					# section declaration

        # Useful offset constants for accessing members of a 
        # struct mp1_blink_struct structure
        LOCATION   = 0    
        ON_CHAR    = 2
        OFF_CHAR   = 3 
        ON_LENGTH  = 4
        OFF_LENGTH = 6
        COUNTDOWN  = 8
        STATUS     = 10
        NEXT       = 12

        STRUCT_SIZE = 16

        UPPER_RANGE = 1999
        ARG_PARAM = 8
        SECOND_INTEGER = 8
        FIRST_INTEGER = 10
        IOCTL_RANGE = 3


# Pointer to head of list (initialized to NULL)
mp1_list_head:
        .long   0

.text					# section declaration

# Export the function symbol names

.global mp1_rtc_tasklet
.global mp1_ioctl

# void mp1_poke(void);
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX
mp1_poke:
        
	movl    vmem_base_addr(,1),%edx
	movb    %cl,(%edx,%eax,1)
	ret



mp1_rtc_tasklet:
        pushl   %ebp                            #basic calling convention
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi
        pushl   %edi
        cmpl    $0, mp1_list_head               #check if head points to NULL
        je      DONE                            #if head->NULL, done
        movl    mp1_list_head, %ebx             #else store mp1_list_head into ebx

CHECKCOUNTDOWN:
        decw    COUNTDOWN(%ebx)                 #decrement COUNT
        movw    COUNTDOWN(%ebx), %ax            #store count into eax
        cmpw    $0, %ax                         #check if COUNT is 0
        je      CHECKSTATUS                     #if so, check STATUS
        jmp     MOVE_ON                         #if not, back the loop again

CHECKSTATUS:
        movw    STATUS(%ebx), %si               #store STATUS into esi
        cmpw    $1, %si                         #check if STATUS is on
        je      PUT_OFF_CHAR                    #if so, put off character
        jmp     PUT_ON_CHAR                     #if not, put on character

PUT_OFF_CHAR:
        movw    $0, STATUS(%ebx)                #set STATUS=0
        xorl    %eax, %eax                      #clear eax
        movw    LOCATION(%ebx), %ax             #store LOCATION into eax
        
        addw    %ax, %ax                        #multiply 2 to eax

        movb    OFF_CHAR(%ebx), %cl             #set parameter for mp1_poke
        call    mp1_poke                        #call mp1_poke

        movw    OFF_LENGTH(%ebx), %dx           #store OFF_LENGTH into edx
        movw    %dx, COUNTDOWN(%ebx)            #put OFF_LENGTH into COUNTDOWN
        jmp     MOVE_ON                         #continue 
        
PUT_ON_CHAR:
        movw    $1, STATUS(%ebx)                #set STATUS=1
        xorl    %eax, %eax                      #clear eax
        movw    LOCATION(%ebx), %ax             #store LOCATION into eax

        addw    %ax, %ax                        #multiply 2 to eax

        movb    ON_CHAR(%ebx), %cl              #set parameter for mp1_poke
        call    mp1_poke                        #call mp1_poke

        movw    ON_LENGTH(%ebx), %dx            #store ON_LENGTH into edx
        movw    %dx, COUNTDOWN(%ebx)            #put ON_LENGTH into COUNTDOWN
        jmp     MOVE_ON                         #continue

MOVE_ON:  
        movl    NEXT(%ebx), %ebx                #move onto the next block
        cmpl    $0, %ebx                        #check if the last
        je      DONE                            #if so, done
        jmp     CHECKCOUNTDOWN                  #otherwise, back to the loop       



mp1_ioctl:
        movl    ARG_PARAM(%esp), %esi           #check the parameter
        cmpl    $IOCTL_RANGE, %esi              #if ranges outside 0-3, return -1
        jg      ERROR
        cmpl    $0, %esi
        jl      ERROR
        jmp     *jumptable(, %esi, 4)           #go to an appropriate function



mp1_ioctl_add:
        pushl   %ebp                            #basic calling convention
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi
        pushl   %edi
        movl    $STRUCT_SIZE, %edi                       #edi=STRUCT_SIZE
        pushl   %edi                            #push edi onto the stack

        movl    ARG_PARAM(%ebp), %esi                   #check arg
        cmpl    $0, %esi                        #if 0, return -1
        je     ERROR

        call    mp1_malloc                      #create new memory
        movl    %eax, %ebx                      #check the return value
        popl    %edi                            #pop edi (param. n for mp1_malloc)

        cmpl    $0, %ebx                        #check if the return value from mp1_malloc is 0 
        je      ERROR                           #if so, return -1

        pushl   %edi                            #push STRUCT_SIZE
        movl    ARG_PARAM(%ebp), %esi                   #move arg into esi
        pushl   %esi                            #push arg
        pushl   %ebx                            #push newly created memory

        call    mp1_copy_from_user              #call function

        popl    %ebx                            #pop parameters off the stack
        popl    %esi
        popl    %edi

        cmpl    $0, %eax                        #check if the return value from mp1_copy_from_user is 0
        jne     MEM_ERROR                       #if so, there's an error

        movw    ON_LENGTH(%ebx), %dx            #copy ON_LENGTH into COUNTDOWN
        movw    %dx, COUNTDOWN(%ebx)

        movl    $1, STATUS(%ebx)                #STATUS=1

        movl    mp1_list_head, %eax             #put mp1_list_head into eax
        movl    %eax, NEXT(%ebx)                #place infront of the head

        movl    %ebx, mp1_list_head             #move head to the appropriate place

        xorl    %eax, %eax                      #clear eax
        movw    LOCATION(%ebx), %ax             #move the LOCATION into eax

        cmpw    $0, %ax                         #see if the location is out of range
        jl      ERROR
        cmpw    $UPPER_RANGE, %ax
        jg      ERROR

        addw    %ax, %ax                        #multiply eax by 2

        movb    ON_CHAR(%ebx), %cl              #put parameters for mp1_poke onto the stack
        call    mp1_poke                        #call function

        jmp     DONE                            #done


MEM_ERROR:
        pushl   %ebx                            #if there's a memory error, free memory
        call    mp1_free
        popl    %ebx

        jmp     ERROR                           #return -1




mp1_ioctl_remove:
        pushl   %ebp                            #basic calling conventions
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi
        pushl   %edi

        movl    mp1_list_head, %ebx             #put mp1_list_head into ebx
        cmpl    $0, mp1_list_head               #compare if head points to 0
        je      ERROR                           #if so, return -1
        movl    ARG_PARAM(%ebp), %esi                   #otherwise, move arg into esi

FIND_LOCATION:  
        cmpw    %si, LOCATION(%ebx)             #check if arg corresponds to current location
        je      REMOVE_LOCATION                 #if so, remove current location
        movl    %ebx, %edi                      #save the previous
        movl    NEXT(%ebx), %ebx                #move onto the next block
        cmpl    $0, %ebx                        #see if reached end of the list
        je      ERROR                           #if so, return -1
        jmp     FIND_LOCATION                   #otherwise, back to the loop 


REMOVE_LOCATION:
        cmpl    %ebx, mp1_list_head             #see if removing head
        je      REMOVE_HEAD                     

        movl    NEXT(%ebx), %edx                #edx = the next block of removing location
        movl    %edx, NEXT(%edi)                #connect the previous block to the edx
        pushl   %ebx                            #push the removing block
        call    mp1_free                        #remove memory
	popl    %ebx                            #pop from stack       

        jmp     SUCCESS                         #return 0


REMOVE_HEAD:
        movl    NEXT(%ebx), %edx                #edx = the next block of removing location
        movl    %edx, mp1_list_head             #move head pointer
        pushl   %ebx                            #push in parameter
        call    mp1_free                        #remove memory
        popl    %ebx                            #pop from stack
        
        jmp     SUCCESS                         #return 0



mp1_ioctl_find:
        pushl   %ebp                            #basic calling conventions
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi
        pushl   %edi
	
        movl    mp1_list_head, %ebx             #ebx=head of the list
        movl    ARG_PARAM(%ebp), %edx                   #edx=arg of ioctl
        movw    LOCATION(%edx), %si             #the LOCATION of the parameter stored into esi

        cmpw    $0, %si                         #see if the LOCATION of the parameter is within the range
        jl      ERROR
        cmpw    $UPPER_RANGE, %si
        jg      ERROR

SEARCH_LOCATION:
        cmpw    %si, LOCATION(%ebx)             #compare the current location with the parameter
        je      COPY_ELEM                       #if they are equal, copy the element
        movl    NEXT(%ebx), %ebx                #if not, move onto the next block
        cmpl    $0, %ebx                        #check if reached end of the list
        je      ERROR                           #if so, return -1
        jmp     SEARCH_LOCATION                 #otherwise, back to the loop

COPY_ELEM:
        movl    $STRUCT_SIZE, %edi                       #put STRUCT_SIZE into edi
        pushl   %edi                            #push parameters for mp1_copy_to_user onto the stack
        pushl   %ebx    
        pushl   %edx                   
        

        call    mp1_copy_to_user                #call fuction

        popl    %edx                            #pop parameters off the stack
        popl    %ebx
        popl    %edi

        cmpl    $0, %eax                        #see if 0 is returned
        jne     ERROR                           #if so, there's an error. return -1
        jmp     SUCCESS                         #otherwise return 0



mp1_ioctl_sync: 
        pushl   %ebp                            #basic calling convention
        movl    %esp, %ebp
        pushl   %ebx
        pushl   %esi
        pushl   %edi 

        movl    mp1_list_head, %ebx             #store the list head into ebx
        movw    FIRST_INTEGER(%ebp), %si                   #check for the first integer
        movw    SECOND_INTEGER(%ebp), %di                    #edi = second integer

FIRST_INT:
        cmpw    %si, LOCATION(%ebx)             #check if the current location matches that of the first integer
        je      SAVE_LOCATION1                  #if so, save that location
        movl    NEXT(%ebx), %ebx                #if not, move to the next block
        cmpl    $0, %ebx                        #if reached end of the list, return -1
        je      ERROR
        jmp     FIRST_INT                       #otherwise, go back to the loop

SAVE_LOCATION1:
        movl    %ebx, %esi                      #save the current location into esi
        movl    mp1_list_head, %ebx             #store the list head into ebx to start comparing with the second integer

SECOND_INT:
        cmpw    %di, LOCATION(%ebx)             #check if the currnet location matches that of the second integer              
        je      SAVE_LOCATION2                  #if so, save that location
        movl    NEXT(%ebx), %ebx                #if not, move onto the next block
        cmpl    $0, %ebx                        #check if reached end of the list
        je      ERROR                           #if so, return -1
        jmp     SECOND_INT                      #if not, back to the loop

SAVE_LOCATION2:
        movl    %ebx, %edi                      #save the current location into edi

COPY:
        movw    ON_LENGTH(%esi), %cx            #copy the ON_LENGTH of the first integer into the second integer
        movw    %cx, ON_LENGTH(%edi)

        movw    OFF_LENGTH(%esi), %cx           #copy the OFF_LENGTH of the first integer into the second integer
        movw    %cx, OFF_LENGTH(%edi)

        movw    COUNTDOWN(%esi), %cx            #copy the COUNTDOWN of the first integer into the second integer
        movw    %cx, COUNTDOWN(%edi)

        movw    STATUS(%esi), %cx               #copy the STATUS of the first integer into the second integer
        movw    %cx, STATUS(%edi)

STATUS_INT2:
        cmpw    $0, %cx                         #check if STATUS is off
        je      PRINT_OFF_CHAR                  #if so, print OFF_CHAR
        jmp     PRINT_ON_CHAR                   #if not, print ON_CHAR


PRINT_OFF_CHAR:
        xorl    %eax, %eax                      #clear eax
        movw    LOCATION(%edi), %ax             #store the location of the second integer into eax
        
        addw    %ax, %ax                        #multiply eax by 2

        movb    OFF_CHAR(%edi), %cl             #have the parameter for mp1_poke
        call    mp1_poke                        #call function
        jmp     SUCCESS                         #return 0


PRINT_ON_CHAR:
        xorl    %eax, %eax                      #clear eax
        movw    LOCATION(%edi), %ax             #store the location of the second integer into eax

        addw    %ax, %ax                        #multiply eax by 2

        movb    ON_CHAR(%edi), %cl              #have the parameter for mp1_poke
        call    mp1_poke                        #call function
        jmp     SUCCESS                         #return 0



SUCCESS:
        movl    $0, %eax                        #return 0
        jmp     DONE                            #done


ERROR:
        movl    $-1, %eax                       #return -1


DONE:
        popl    %edi                            #pop elements off the stack
        popl    %esi
        popl    %ebx
        leave
        ret                                     #DONE!!!


jumptable:
        .long mp1_ioctl_add, mp1_ioctl_remove, mp1_ioctl_find, mp1_ioctl_sync           #jumptable for ioctl functions

.end
