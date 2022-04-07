;http://www.sources.ru/magazine/0805/asm.html
;http://radiofront.narod.ru/htm/prog/htm/winda/api/paint.html
;http://www.programmersforum.ru/showthread.php?t=61473
.386      
.model flat, stdcall
option casemap :none                                   
                          
include <\masm32\include\windows.inc>
include <\masm32\include\kernel32.inc>
include <\masm32\include\user32.inc>
include <\masm32\include\gdi32.inc>

includelib <\masm32\lib\kernel32.lib>
includelib <\masm32\lib\user32.lib>
includelib <\masm32\lib\gdi32.lib>
includelib <\masm32\lib\shell32.lib>
RGB macro red,green,blue
	 xor 	 eax,eax
	 mov 	 ah,blue
	 shl 	 eax,8
	 mov 	 ah,green
	 mov 	 al,red
endm

.data
hWnd  dd ? ;хэндл окна
hDC   dd ? ;его DC
hBmp  dd ? ;хэндл битмапа
BmpDC dd ? ;его DC сюда рисуем, после чего выведем его на окно
_W    dd ? ;ширина и высота рисуемой области
_H    dd ?
hInst HINSTANCE ? ;номер приложения в системе
WindowClass db "Tetris3DForm",0 
Caption db "Тетрис 3D",0
Hg dd 580  ;мнимая высота рисунка
dY dd -100 ;начало рисунка относительно мнимой высоты
xc dd 300  ;центр стакана
x0 dd -5   ;левый край стакана
z0 dd 3    ;дно стакана
xs dd 24   ;точка зрения по Х на экран
ys dd 9    ;точка зрения по Y на экран
x  dd ?    ;3 физических координаты точки для их последующего рисования
y  dd ?
z  dd ?
x1 dd ?    ;координаты точек для рисования на мониторе
x2 dd ?
x3 dd ?
x4 dd ?
y1 dd ?
y2 dd ?
y3 dd ?
y4 dd ?
Gl dw 200 dup(255) ;массив стакана, из двух байт, младший байт цвет, 255-пустой,
; старший 0-от старого, 1-от текущей фигуры
plg dd 8 dup(?) ;массив четырехугольника для его рисования
Clr db 255,0,0, 0,255,0, 0,0,255, 0,128,128, 165,42,42, 255,140,0, 148,0,211, 128,128,128 ;массив цветов
Fig dd 9 dup(?) ;массив фигуры плюс её цвет
tFg dd 8 dup(?) ;тестовый массив фигуры, для проверки при повороте
Figs dd 0,1,1,1,2,1,3,1 ;массивы фигур относительно квадрата xFig,yFig верхний левый угол
     dd 1,0,1,1,1,2,1,3
     dd 0,1,1,1,2,1,3,1
     dd 1,0,1,1,1,2,1,3
    ;
     dd 1,0,1,1,2,1,1,2
     dd 1,0,0,1,1,1,2,1
     dd 1,0,0,1,1,1,1,2
     dd 0,1,1,1,2,1,1,2
    ;
     dd 0,1,1,1,1,2,2,2
     dd 1,0,0,1,1,1,0,2
     dd 0,1,1,1,1,2,2,2
     dd 1,0,0,1,1,1,0,2
    ;
     dd 1,1,2,1,0,2,1,2
     dd 0,0,0,1,1,1,1,2
     dd 1,1,2,1,0,2,1,2
     dd 0,0,0,1,1,1,1,2
    ;
     dd 2,0,0,1,1,1,2,1
     dd 0,0,1,0,1,1,1,2
     dd 0,1,1,1,2,1,0,2
     dd 1,0,1,1,1,2,2,2
    ;
     dd 0,1,1,1,2,1,2,2
     dd 1,0,2,0,1,1,1,2
     dd 0,0,0,1,1,1,2,1
     dd 1,0,1,1,0,2,1,2
    ;
     dd 1,1,2,1,1,2,2,2
     dd 1,1,2,1,1,2,2,2
     dd 1,1,2,1,1,2,2,2
     dd 1,1,2,1,1,2,2,2
Tmr dd 0    ;идентификатор таймера
Start db 0  ;флаг что игра запущена
Check db 0  ;флаг что идет проверка на ряды 
xFig dd ?   ;координаты квадрата в фигуре
yFig dd ?
pFig dd ?   ;текущая позиция фигуры
Scr  dd 0   ;количество очков
Lvl  dd 1   ;номер уровня
FntStr db "Courier",0 ;тип шрифта и прочая бла бла
ScrStr db "Score:           "
LvlStr db "Level:           "
UseStr db "Enter ",27," ",26,24," Space Esc"
NewStr db "Для продолжения Enter"
frm db "%-9d", 0
ScrLvl dd ? ;переход от уровня к уровню
dScr  dd ?  ;цена удаленного ряда 
Pause dd ?  ;пауза таймера
Stop  db ?  ; игра окончена
Trn   dd ?


MsgBoxCaption db "                       GAME OVER!",0
MsgBoxText    db "Для продолжения игры нажмите Enter",0
.code
start:

    invoke GetModuleHandle, NULL 
    mov hInst, eax
    call   MainWin
    invoke ExitProcess, 0
;основная процедура создается окно и транслируются события на нем
MainWin proc
LOCAL wc :WNDCLASSEX
LOCAL   msg :MSG

    invoke GetModuleHandle, NULL 
    mov hInst, eax
    mov      wc.cbSize,SIZEOF WNDCLASSEX
    mov      wc.style,CS_HREDRAW or CS_VREDRAW
    mov      wc.lpfnWndProc,OFFSET WndProc
    mov      wc.cbClsExtra,NULL
    mov      wc.cbWndExtra,NULL
    push     hInst
    pop      wc.hInstance
    mov      wc.lpszClassName,OFFSET WindowClass
    invoke   LoadIcon,NULL,IDI_APPLICATION
    mov      wc.hIcon,eax
    mov      wc.hIconSm,eax
    invoke   LoadCursor,NULL,IDC_ARROW
    mov      wc.hCursor,eax
    invoke   RegisterClassEx,addr wc
    invoke CreateWindowEx, 0, addr WindowClass, addr Caption, WS_OVERLAPPEDWINDOW, 100, 100, 610, 480,0,0,hInst,0
    mov hWnd, eax
    invoke ShowWindow, hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, hWnd
    call ClearGl
    call Picture
    ; Цикл обработки сообщений (стандартный)
     .WHILE TRUE
         INVOKE   GetMessage,ADDR msg,0,0,0  ; ожидаем и получаем сообщение
         .BREAK .IF (!eax)                   ; выходим из цикла, если получаем WM_QUIT (выход из приложения)
         INVOKE   TranslateMessage,ADDR msg  ; преобразуем символьные сообщения
         INVOKE   DispatchMessage,ADDR msg   ; обрабатываем сообщение
     .ENDW
     mov      eax,msg.wParam
MainWin endp 
;проседура обработки нажатия клавиш
WndProc proc  Wnd:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    .IF uMsg == WM_DESTROY
        cmp dword ptr Tmr, 0
        je j0C
        invoke KillTimer, hWnd, Tmr
    j0C:invoke   PostQuitMessage,NULL
    .ELSEIF uMsg == WM_TIMER
        cmp byte ptr Check, 0
        jne j0G
        call Down
j0G:.ELSEIF uMsg == WM_KEYDOWN
        .IF Check == 0
            .IF wParam == VK_RIGHT
                cmp byte ptr Start, 0
                je j0D
                call Right
        j0D:.ELSEIF  wParam == VK_LEFT
                cmp byte ptr Start, 0
                je j0E
                call Left
        j0E:.ELSEIF  wParam == VK_UP
                cmp byte ptr Start, 0
                je j0H
                mov dword ptr Trn, 1
                call Turn
        j0H:.ELSEIF  wParam == VK_DOWN
                cmp byte ptr Start, 0
                je j0I
                mov dword ptr Trn, -1
                call Turn
        j0I:.ELSEIF  wParam == VK_ESCAPE
                cmp dword ptr Tmr, 0
                je j0B
                invoke KillTimer, hWnd, Tmr
            j0B:invoke   DestroyWindow, Wnd
            .ELSEIF  wParam == VK_RETURN
                call ClearGl
                mov byte ptr Start, 1
                cmp dword ptr Tmr, 0
                je j0A
                invoke KillTimer, hWnd, Tmr
            j0A:mov dword ptr Pause, 600
                invoke SetTimer, hWnd, 502, Pause, NULL
                mov Tmr, eax
                mov dword ptr Scr, 0
                mov dword ptr Lvl, 1
                mov dword ptr ScrLvl, 100
                mov dword ptr dScr, 10
                mov byte ptr Stop, 0
                call NewFig
            .ELSEIF  wParam == VK_SPACE
                cmp byte ptr Start, 0
                je j0F
                call Drop
        j0F:.ENDIF
        .ENDIF
    .ELSEIF uMsg == WM_SIZE 
        call Picture
    .ELSE
        invoke   DefWindowProc,Wnd,uMsg,wParam,lParam
        ret
    .ENDIF
    xor  eax,eax
    ret
WndProc endp
;проседура чистит стакан
Clear proc
LOCAL rc: RECT
LOCAL bWhite: HBRUSH 
LOCAL pWhite: HPEN 
    RGB 255,255,255
    invoke CreateSolidBrush, eax
    mov bWhite, eax
    invoke SelectObject, BmpDC, bWhite
    RGB 255,255,255
    invoke CreatePen, PS_SOLID, 1, eax
    mov pWhite, eax
    invoke SelectObject, BmpDC, pWhite
    invoke GetClientRect, hWnd, addr rc
    invoke Rectangle, BmpDC, 0, 0, rc.right, rc.bottom
    invoke DeleteObject, bWhite
    invoke DeleteObject, pWhite
    ret
Clear endp
;получает координаты [esi],[edi]на мониторе от x,y,z
GetXY proc
LOCAL a: DWORD
    mov eax, z
    mov ebx, 3
    mul ebx
    add eax, xs
    add eax, z0
    mul dword ptr ys
    mov a, eax
    mov eax, Hg
    mul dword ptr xs
    imul dword ptr x
    idiv dword ptr a
    add eax, xc
    mov [esi], eax
    mov eax, Hg
    mul dword ptr xs
    mul dword ptr y
    div dword ptr a
    add eax, dY
    mov [edi], eax
    ret
GetXY endp
;рисует стакан
Glass proc
LOCAL pBlack: HPEN
    RGB 0, 0, 0
    invoke CreatePen, PS_SOLID, 1, eax
    mov pBlack, eax
    invoke SelectObject, BmpDC, pBlack
    mov ecx, 21
j00:mov eax, -5
    mov x, eax
    mov eax, ys
    mov dword ptr y, eax
    mov dword ptr z, 21
    sub z, ecx
    lea esi, x1
    lea edi, y1
    call GetXY 
    mov eax, 5
    mov x, eax
    mov eax, ys
    mov dword ptr y, eax
    mov dword ptr z, 21
    sub z, ecx
    lea esi, x2
    lea edi, y2
    call GetXY
    push ecx
    invoke  MoveToEx, BmpDC, x1, y1, NULL
    invoke LineTo, BmpDC, x2, y2
    pop ecx
    dec ecx
    jnz j00
    mov ecx, 11
j02:mov eax, 6
    sub eax, ecx
    mov x, eax
    mov eax, ys
    mov y, eax
    mov eax, 0
    mov z, eax
    lea esi, x1
    lea edi, y1
    call GetXY
    add dword ptr z, 20
    lea esi, x2
    lea edi, y2
    call GetXY
    push ecx
    invoke  MoveToEx, BmpDC, x1, y1, NULL
    invoke LineTo, BmpDC, x2, y2
    pop ecx
    loop j02
    invoke DeleteObject, pBlack
    ret
Glass endp
;чистит стакан
ClearGl proc
    cld
    mov ax, 255
    mov ecx, 200
    lea edi, Gl
rep stosw
    ret
ClearGl endp    
;рисует четырехугольники
Cubes proc
LOCAL pBlack: HPEN
LOCAL bColor: HBRUSH
LOCAL _Plg: DWORD 
LOCAL xx: DWORD
LOCAL zz: DWORD

    RGB 0, 0, 0
    invoke CreatePen, PS_SOLID, 1, eax
    mov pBlack, eax
    invoke SelectObject, BmpDC, pBlack
    RGB 255,0,0
    invoke CreateSolidBrush, eax
    mov bColor, eax
    invoke SelectObject, BmpDC, bColor

    lea esi, plg
    mov _Plg, esi
    mov dword ptr zz, 0
j03:mov dword ptr xx, 0
j04:mov eax, xx
    cmp eax, 5
    jb j05
    neg eax
    add eax, 14
j05:mov x, eax
    mov eax, zz
    mov ebx, 20
    mul ebx
    add eax, x
    add eax, x
    lea esi, Gl
    cmp byte ptr[esi+eax],255
    je j06
    mov bl, [esi+eax]
    xor eax, eax
    mov al, bl
    mov ebx, 3
    mul ebx
    lea esi, Clr
    mov bl, byte ptr[esi+eax]
    mov cl, byte ptr[esi+eax+1]
    mov dl, byte ptr[esi+eax+2]
    RGB bl,cl,dl
    invoke CreateSolidBrush, eax
    mov bColor, eax
    invoke SelectObject, BmpDC, bColor

    ; 
    mov eax, 19
    sub eax, zz
    mov z, eax
    push dword ptr x
    mov eax, x
    sub eax, 5
    mov x, eax
    mov dword ptr y, 8
    lea esi, x1
    lea edi, y1
    call GetXY
    inc dword ptr x
    mov dword ptr y, 9
    lea esi, x2
    lea edi, y2
    call GetXY
    mov esi, _Plg
    mov eax, x1
    mov [esi], eax
    mov eax, y1
    mov [esi+4], eax
    mov eax, x2
    mov [esi+8], eax
    mov eax, y1
    mov [esi+12], eax
    mov eax, x2
    mov [esi+16], eax
    mov eax, y2
    mov [esi+20], eax
    mov eax, x1
    mov [esi+24], eax
    mov eax, y2
    mov [esi+28], eax
    invoke Polygon, BmpDC, addr plg, 4
    ;
    dec dword ptr x
    mov dword ptr y, 8
    inc dword ptr z
    lea esi, x3
    lea edi, y3
    call GetXY
    inc dword ptr x
    mov dword ptr y, 9
    lea esi, x4
    lea edi, y4
    call GetXY
    mov esi, _Plg
    pop ebx
    cmp ebx, 5
    jae j07
    mov eax, x2
    mov [esi], eax
    mov eax, y1
    mov [esi+4], eax
    mov eax, x2
    mov [esi+8], eax
    mov eax, y2
    mov [esi+12], eax
    mov eax, x4
    mov [esi+16], eax
    mov eax, y4
    mov [esi+20], eax
    mov eax, x4
    mov [esi+24], eax
    mov eax, y3
    mov [esi+28], eax
    jmp j08
j07:mov eax, x1
    mov [esi], eax
    mov eax, y1
    mov [esi+4], eax
    mov eax, x1
    mov [esi+8], eax
    mov eax, y2
    mov [esi+12], eax
    mov eax, x3
    mov [esi+16], eax
    mov eax, y4
    mov [esi+20], eax
    mov eax, x3
    mov [esi+24], eax
    mov eax, y3
    mov [esi+28], eax
j08:invoke Polygon, BmpDC, addr plg, 4
    ;
    mov eax, x3
    mov [esi], eax
    mov eax, y3
    mov [esi+4], eax
    mov eax, x4
    mov [esi+8], eax
    mov eax, y3
    mov [esi+12], eax
    mov eax, x2
    mov [esi+16], eax
    mov eax, y1
    mov [esi+20], eax
    mov eax, x1
    mov [esi+24], eax
    mov eax, y1
    mov [esi+28], eax
    invoke Polygon, BmpDC, addr plg, 4
    invoke DeleteObject, bColor
    ;
j06:inc dword ptr xx
    cmp dword ptr xx, 10
    jb j04
    inc dword ptr zz
    cmp dword ptr zz, 20
    jb j03 
    invoke DeleteObject, pBlack
    ret
Cubes endp    
;рисует общую картину
Picture proc
LOCAL hOld:DWORD
LOCAL rc: RECT

    invoke GetClientRect, hWnd, addr rc
    mov eax, rc.right
    sub eax, rc.left 
    inc eax
    mov _W, eax
    mov eax, rc.bottom
    sub eax, rc.top 
    inc eax
    mov _H, eax
    invoke GetWindowDC, hWnd 
    mov hDC, eax
    invoke CreateCompatibleBitmap, hDC, _W, _H
    mov hBmp, eax
    invoke CreateCompatibleDC, hDC
    mov BmpDC, eax
    invoke SelectObject, BmpDC, hBmp
    mov hOld, eax
    call Clear
    call Text
    call Glass
    call Cubes 
    invoke BitBlt, hDC, 10, 30, _W, _H, BmpDC, 0, 0, SRCCOPY
    invoke SelectObject,hDC, hOld
    invoke ReleaseDC, hWnd, hDC
    invoke DeleteDC, hDC
    invoke DeleteObject, hBmp                       
    invoke DeleteDC, BmpDC
    ret
Picture endp  
;проверяет можно ли нарисовать новую фигуру
NewFig proc
LOCAL Col:WORD
LOCAL sys:SYSTEMTIME
    cmp byte ptr Start, 1
    jne j11
    cld
    invoke GetSystemTime, addr sys
    xor dx, dx
    mov ax, sys.wMilliseconds
    mov ebx, 7
    div ebx
    mov eax, edx
    lea esi, Figs
    lea edi, Fig
    mov [edi+32], eax
    mov ebx, 128
    mul ebx
    add esi, eax
    mov ecx, 8
rep movsd  
    lea esi, Fig
    mov eax, [esi+4]
    neg eax
    mov yFig, eax
    mov ecx, 4 
j12:add dword ptr[esi], 3
    add [esi+4], eax
    add esi, 8
    loop j12
    lea esi, Fig
    call TestFig
    or eax, eax
    jnz j11
    mov byte ptr Start, 0
    mov byte ptr Stop, 1
    invoke KillTimer, hWnd, Tmr
    call Picture
    ret
    ;
j11:mov dword ptr xFig, 3
    mov dword ptr pFig, 0
    lea esi, Fig
    lea edi, Gl
    mov ax, [esi+32]
    mov ah, 1
    mov Col, ax
    mov ecx, 4
j10:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov bx, Col
    mov [edi+eax], bx
    add esi, 8
    loop j10
    call Picture
    ret
NewFig endp
;обсчитывает если нажата space
Down proc
LOCAL Col:WORD
LOCAL n:BYTE
    
    lea esi, Fig
    lea edi, Gl
    mov ax, [esi+32]
    mov ah, 1
    mov Col, ax
    ;
    mov byte ptr n, 4
j25:cmp dword ptr[esi+4], 19
    je j23
    mov eax, [esi+4]
    inc eax
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    cmp byte ptr[edi+eax], 255
    je j20
    cmp byte ptr[edi+eax+1], 1
    je j20
j23:mov ecx, 4
    lea esi, Fig
j21:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov byte ptr[edi+eax+1], 0
    add esi, 8
    loop j21
    call CheckGl 
    jmp j22
j20:add esi,8
    dec byte ptr n
    jnz j25
    mov ecx, 4
    lea esi, Fig
j24:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov word ptr[edi+eax], 255
    add esi, 8
    loop j24
    inc dword ptr yFig
    mov ecx, 4
    lea esi, Fig
j26:inc dword ptr[esi+4]
    mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov bx, Col
    mov word ptr[edi+eax], bx
    add esi, 8
    loop j26

    call Picture
j22:ret
Down endp    
;обсчитывает если нажата left
Left proc
LOCAL Col:WORD
LOCAL n:BYTE
    
    lea esi, Fig
    lea edi, Gl
    mov ax, [esi+32]
    mov ah, 1
    mov Col, ax
    ;
    mov byte ptr n, 4
j31:cmp dword ptr[esi], 0
    je j30
    mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    mov ebx, [esi]
    dec ebx
    shl ebx,1
    add eax, ebx
    cmp byte ptr[edi+eax], 255
    je j32
    cmp byte ptr[edi+eax+1], 0
    je j30
j32:add esi,8
    dec byte ptr n
    jnz j31
    mov ecx, 4
    lea esi, Fig
j33:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov word ptr[edi+eax], 255
    add esi, 8
    loop j33
    dec dword ptr xFig
    mov ecx, 4
    lea esi, Fig
j34:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    mov ebx, [esi]
    dec ebx
    shl ebx, 1
    add eax, ebx
    mov bx, Col
    mov word ptr[edi+eax], bx
    dec dword ptr[esi]
    add esi, 8
    loop j34

    call Picture
j30:ret
Left  endp 
;обсчитывает если нажата right
Right proc
LOCAL Col:WORD
LOCAL n:BYTE
    
    lea esi, Fig
    lea edi, Gl
    mov ax, [esi+32]
    mov ah, 1
    mov Col, ax
    ;
    mov byte ptr n, 4
j41:cmp dword ptr[esi], 9
    je j40
    mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    mov ebx, [esi]
    inc ebx
    shl ebx,1
    add eax, ebx
    cmp byte ptr[edi+eax], 255
    je j42
    cmp byte ptr[edi+eax+1], 0
    je j40
j42:add esi,8
    dec byte ptr n
    jnz j41
    mov ecx, 4
    lea esi, Fig
j43:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov word ptr[edi+eax], 255
    add esi, 8
    loop j43
    inc dword ptr xFig
    mov ecx, 4
    lea esi, Fig
j44:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    mov ebx, [esi]
    inc ebx
    shl ebx, 1
    add eax, ebx
    mov bx, Col
    mov word ptr[edi+eax], bx
    inc dword ptr[esi]
    add esi, 8
    loop j44

    call Picture
j40:ret
Right endp
;при ввводе новой фигуры проверяет есть ли место, 
;а при повороте проверяет не вышли ли за край стакана и не залезли в старые фигуры, 
;для начала проверяет tFg, если устраивает копирует его в Fig
TestFig proc
    mov edi, esi
    mov ecx, 4
j53:cmp dword ptr[edi], 0
    jl j51
    cmp dword ptr[edi], 9
    ja j51
    cmp dword ptr[edi+4], 0
    jl j51
    cmp dword ptr[edi+4], 19
    ja j51
    add edi, 8
    loop j53
    lea edi, Gl
    mov ecx, 4
j52:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    cmp byte ptr[edi+eax], 255
    je j50
    cmp byte ptr[edi+eax+1], 1
    je j50
j51:xor eax, eax
    ret
j50:add esi, 8
    loop j52
    mov eax, 1
    ret
TestFig endp    
;при нажатии на пробел считает min на сколько можно сбросить
Drop proc
LOCAL Col:WORD
LOCAL min:DWORD
LOCAL h:DWORD
    mov dword ptr min, 20
    lea esi, Fig
    lea edi, Gl
    mov ax, [esi+32]
    mov Col, ax
    ;
    mov ecx, 4
j61:mov eax, [esi+4]
    cmp eax, 19
    jne j68
    mov ecx, 4
j60:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov byte ptr[esi+eax+1], 0
    loop j60
    jmp j69
j68:mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    cmp byte ptr[edi+eax+20], 255
    je j62
    cmp byte ptr[edi+eax+21], 0
    jne j65
    mov ecx, 4
j6A:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov byte ptr[esi+eax+1], 0
    loop j6A
    jmp j69
j62:mov dword ptr h, 0
j64:add eax, 20
    cmp eax, 400
    jae j63
    cmp byte ptr[edi+eax], 255
    jne j63
    inc dword ptr h
    jmp j64
j63:mov eax, h
    cmp eax, min
    jae j65
    mov min, eax
j65:add esi, 8
    dec ecx
    jnz j61
    lea esi, Fig
    mov ecx, 4
j66:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov word ptr[edi+eax], 255
    add esi, 8
    loop j66
    lea esi, Fig
    mov ecx, 4
j67:mov eax, min
    add [esi+4], eax
    mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov bx, Col
    mov [edi+eax], bx
    add esi, 8
    loop j67
j69:call CheckGl 
    ret
Drop endp 
;проверяет заполненные ряды, если есть - удаляет
CheckGl proc
LOCAL was:BYTE
LOCAL h1:DWORD
LOCAL h2:DWORD
    mov byte ptr Check, 1   
    mov byte ptr was, 0
    mov dword ptr h1, 20
    mov dword ptr h2, 20
    lea esi, Gl
    mov dword ptr y, 20
j72:mov ecx, 10
j71:cmp byte ptr[esi+ecx*2-2], 255
    je j70
    loop j71
j70:or ecx, ecx
    jnz j73
    mov byte ptr was, 1
    mov ecx, 10
j74:mov byte ptr[esi+ecx*2-2], 7
    loop j74
j73:add esi, 20
    dec dword ptr y
    jnz j72
    cmp byte ptr was, 0
    je j75
    call Picture
    invoke Sleep, 500
    ;
    mov dword ptr y, 19
j7A:mov eax, y
    mov ebx, 20
    mul ebx
    lea esi, Gl
    add esi, eax
    mov ecx, 10
j77:cmp byte ptr[esi+ecx*2-2], 7
    jne j76
    loop j77
j76:or ecx, ecx
    jnz j78
    mov ecx, 10
j7B:mov byte ptr[esi+ecx*2-2], 255
    loop j7B
    mov eax, y
    cmp dword ptr h1, 20
    jne j79
    mov h1, eax
j79:mov h2, eax
j78:dec dword ptr y
    jns j7A
    mov eax, h1
    cmp eax, 20
    je j75
    cmp dword ptr h2, 0
    je j7C
    std
    mov ebx, 20
    mul ebx
    lea edi, Gl
    add edi, eax
    add edi, 18
    mov eax, h2
    dec eax
    mov ebx, 20
    mul ebx
    lea esi, Gl
    add esi, eax
    add esi, 18
    mov eax, h2
    mov ebx, 10
    mul ebx
    mov ecx, eax
rep movsw  
j7C:mov eax, h1
    sub eax, h2
    inc eax
    mul dword ptr dScr
    add Scr, eax 
    mov eax, Scr 
    xor edx, edx
    div dword ptr ScrLvl
    cmp eax, Lvl
    jb j75
    cmp dword ptr Lvl, 10
    je j75
    inc  dword ptr Lvl
    inc  dword ptr dScr
    invoke KillTimer, hWnd, Tmr
    sub  dword ptr Pause, 50
    invoke SetTimer, hWnd, 502, Pause, NULL
    mov Tmr, eax
j75:call NewFig
    mov byte ptr Check, 0
    ret
CheckGl endp    
;при повороте из Figs берет фигуру, pFig текущая позиция фигуры
Turn proc
LOCAL Old:DWORD
LOCAL Col:WORD
    cld
    lea esi, Figs
    lea edi, Fig
    mov eax, [edi+32]
    mov ah, 1
    mov Col, ax
    mov ah, 0
    mov ebx, 128
    mul ebx
    add esi, eax
    mov eax, pFig
    mov Old, eax
    add eax, 4
    add eax, Trn
    xor edx, edx
    mov ebx, 4
    div ebx
    mov pFig, edx
    mov eax, edx
    mov ebx, 32
    mul ebx
    add esi, eax
    lea edi, tFg
    mov ecx, 8
rep movsd
    mov eax, xFig
    mov ebx, yFig
    lea esi, tFg
    mov ecx, 4 
j81:add [esi], eax
    add [esi+4], ebx
    add esi, 8
    loop j81
    lea esi, tFg
    call TestFig
    or eax, eax
    jnz j80
    mov eax, Old
    mov pFig, eax
    ret
j80:lea esi, Fig
    lea edi, Gl
    mov ecx, 4
j82:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov word ptr[edi+eax], 255
    add esi, 8
    loop j82
    lea esi, tFg
    lea edi, Fig
    mov ecx, 8
rep movsd   
    lea esi, Fig
    lea edi, Gl
    mov ecx, 4
j83:mov eax, [esi+4]
    mov ebx, 20
    mul ebx
    add eax, [esi]
    add eax, [esi]
    mov bx, Col 
    mov word ptr[edi+eax], bx
    add esi, 8
    loop j83
    call Picture
    ret
Turn endp    
;выводит надписи
Text proc
LOCAL Fnt:HFONT

    mov eax, DEFAULT_PITCH
    and eax, FF_DECORATIVE
    invoke CreateFont,11,6,0,0,FW_NORMAL,0,0,0,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,eax,addr FntStr
    mov Fnt, eax
    RGB 148,0,211
    invoke SetTextColor, BmpDC, eax
    invoke TextOutA, BmpDC, 1, 60,addr UseStr, 20
    RGB 0,0,0
    invoke SetTextColor, BmpDC, eax
    lea eax, ScrStr
    add eax, 7
    invoke wsprintf, eax, addr frm, Scr
    invoke TextOutA, BmpDC, 1, 10,addr ScrStr, 16
    lea eax, LvlStr
    add eax, 7
    invoke wsprintf, eax, addr frm, Lvl
    invoke TextOutA, BmpDC, 1, 30,addr LvlStr, 16

    cmp byte ptr Stop, 0
    je jA0
    RGB 255,0,0
    invoke SetTextColor, BmpDC, eax
    ;invoke TextOutA, BmpDC, 1, 120,addr NewStr, 21
    invoke MessageBox, NULL, addr MsgBoxText, addr MsgBoxCaption, MB_OK
    mov byte ptr Stop, 0
jA0:invoke DeleteObject, Fnt
    ret
Text endp    

end start
