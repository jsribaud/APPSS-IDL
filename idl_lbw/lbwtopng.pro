;+
;NAME:
;  lbwtopng - Make a nice PNG file of an LBW source
;SYNTAX: lbwtopng, lbwsrc, filename, _EXTRA=_EXTRA
;ARGS:
;OPTIONAL ARGUMENTS:
;KEYWORDS:
;
;DESCRIPTION:
; 
;HISTORY:
;
;   RK: Nov13   Original version (alterations to plotlbw)
;   GH: Dec13   Split off into own procedure, additional plotting functionality
;   GH: Jan17   Added EPS plotting functionality
;-

PRO lbwtopng, lbwsrc, filename, eps=eps, _EXTRA=_EXTRA

; Did the user specify a filename? If not, use the default (HI source name)
if n_elements(filename) eq 0 then filename = lbwsrc.LBWsrcname
; Ensure a proper file extension (.png)
if strpos(strlowcase(filename), '.png') eq -1 and not(keyword_set(eps)) then filename = filename + '.png'
if strpos(strlowcase(filename), '.eps') eq -1 and keyword_set(eps)      then filename = filename + '.eps'

if keyword_set(eps) then epsinit, filename, /color, xsize=8, ysize=4.5

; Produce a plot
lbwplot, lbwsrc, eps=eps, _EXTRA=_EXTRA

; Is it an EPS file? Then just
if keyword_set(eps) then begin

    epsterm

; It must not be an EPS. Read it from the plot and write a PNG file.
endif else begin

    ; Get the plot data into an array
    image = tvrd(/true)

    ; Write the array to a png file
    write_png, filename, image, /verbose

endelse

END
