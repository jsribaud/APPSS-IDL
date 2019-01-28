PRO lbwcomments, lbwsrc, newcomment, linenumber, add=add, view=view, edit=edit

	if keyword_set(add) then begin
		lbwsrc.comments.text[lbwsrc.comments.count] = newcomment
		lbwsrc.comments.count += 1
		return
	endif

	if keyword_set(view) then for i=0L, lbwsrc.comments.count-1 do print, strtrim(i,2)+' '+lbwsrc.comments.text[i]

	if keyword_set(edit) then lbwsrc.comments.text[linenumber] = newcomment

END

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
;   GH: Jan17   Commenting out function; it's been made into file lbwtopng.pro
;-

;PRO lbwtopng, lbwsrc, filename, _EXTRA=_EXTRA

; Did the user specify a filename? If not, use the default (HI source name)
;if n_elements(filename) eq 0 then filename = lbwsrc.LBWsrcname
; Ensure a proper file extension (.png)
;if strpos(filename, '.png') eq -1 then filename = filename + '.png'

; Produce a plot
;lbwplot, lbwsrc, _EXTRA=_EXTRA

; Get the plot data into an array
;image = tvrd(/true)

; Write the array to a png file
;write_png, filename, image, /verbose

;END
