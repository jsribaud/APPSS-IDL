;+
;NAME:
;  lbwplot - Make a nice plot of an LBW spectrum
;SYNTAX: lbwplot, lbwsrc, freq=freq, xrange=xrange, yrange=yrange, hires=hires
;ARGS:
;OPTIONAL ARGUMENTS:
;KEYWORDS:
;
;DESCRIPTION:
; 
;HISTORY:
;
;   GH: Jan13    Original version
;   GH: Jan17    Added a single line for EPS functionality
;-

PRO scaleplotlbw, lbwsrc

TRUE = 1
FALSE = 0

yrange = lbwsrc.yrange ; Initialize to default y-scaling

; Give the user some instructions
print
print, 'Find a good range for plot:'
print
print, '  Give [min, max] range to vertically rescale plot.'
print, '  Press [enter] to accept ranges.'
;print, '  Enter h for extended help.'

; Loop for user input
prelim = TRUE
while prelim do begin

	; Make a nice plot
	lbwplot, lbwsrc, yrange=yrange

	; Get user response
	response = ''
	read, response

	; Process the user response
	if response eq '' then break	; User pressed enter and wants to continue

	; Use the magic of regular expressions to find the y ranges given
	regex = '(-?[0-9.]+)[, ]*(-?[0-9.]+)' ; This matches two numbers of the form -##.###
	                                      ; Possibly split by commas and spaces
	newyrange = stregex(response, regex, /extract, /subexpr)
	newyrange = [float(newyrange[1]), float(newyrange[2])]
	; Did it actually find new numbers?
	if newyrange[0] ne 0. or newyrange[1] ne 0. then begin
		; Is this new range sensible?
		if max(newyrange) le min(lbwsrc.spec) or min(newyrange) ge max(lbwsrc.spec) then begin
			print, 'Spectrum is out of range! Give new values!'
			continue
		endif
		yrange = [min(newyrange), max(newyrange)]
	endif

endwhile

lbwsrc.yrange = yrange ; Make this scale the default for now

END

PRO regionmasklbw, lbwsrc, regions, srcmask=srcmask
	
	mask = lbwsrc.mask
	if n_elements(srcmask) ne 0 then mask = lbwmask.srcmask  ; Finding the source's mask instead?

	maskchan = where(lbwsrc.mask ne 0)

	regions = [maskchan[0], maskchan[0]]
	nr = 0L

	for i=1L, n_elements(maskchan)-1 do begin
		; Is this adjacent to the previous channel?
		if maskchan[i] eq regions[2*nr+1]+1 then begin
			regions[2*nr+1] = maskchan[i]
		endif else begin
			regions = [regions, maskchan[i], maskchan[i]]
			nr += 1
		endelse
	endfor
END

PRO lbwplot, lbwsrc, raw=raw, smooth=smooth, xrange=xrange, yrange=yrange, mask=mask, freq=freq, eps=eps

if not(keyword_set(eps)) then window, xsize=1000, ysize=650

if n_elements(freq) ne 0 then begin
	xvals = lbwsrc.freq
	xtitle = 'Frequency (MHz)'
endif else begin
	xvals = lbwsrc.vel
	xtitle = textoidl('Velocity (km s^{-1})')
endelse

; Did the user specify that the spectrum should be smoothed, etc.?
spectrum = lbwsrc.spec
if keyword_set(smooth) then begin
	lbwsmooth, lbwsrc, smooth, spectrum, /noreplace
end

if keyword_set(raw) then begin
	spectrum = lbwsrc.raw
;	stop
endif

; Did the user specify an x range?
if n_elements(xrange) eq 2 then begin
	xmin = xrange[0]
	xmax = xrange[1]
endif else begin
	xmin = min(xvals)
	xmax = max(xvals)
endelse

; Did the user specify a y range?
if n_elements(yrange) eq 0 then yrange=-999
if n_elements(yrange) eq 2 and yrange[0] ne -999 then begin
	ymin = yrange[0]
	ymax = yrange[1]
endif else begin
	tmpspec = spectrum
	; Has the user done masking (i.e. lbwbaseline) yet?
	if (where(lbwsrc.mask))[0] ne -1 then begin
		; If so, we should only look over the range inside of the masks
		; (for high-order fits, the edges of the bandpass may have large negative "fits")
		maskleft = min(where(lbwsrc.mask))
		maskright = max(where(lbwsrc.mask))

		tmpspec = spectrum[maskleft:maskright]
	endif

    rangey = max(tmpspec)-min(tmpspec) 
	ymin = min(tmpspec)-0.05*rangey
	ymax = max(tmpspec)+0.05*rangey

	; Wait wait is there a default y range?
	if n_elements(lbwsrc.yrange) eq 2 and lbwsrc.yrange[0] ne -999 then begin
		ymin = lbwsrc.yrange[0]
		ymax = lbwsrc.yrange[1]
	endif
endelse

; Set axis scales
hor, xmin, xmax
ver, ymin, ymax

; Plot empty axes!
loadct, 0, /silent
plot, [0,0],[0,0], /nodata, $
  xtitle=xtitle, ytitle='Flux Density (mJy)', $
  title = lbwsrc.LBWsrcname, $
  charsize=1.5

; Set a color because WHY NOT?
loadct, 13, /silent
oplot, xvals, spectrum, color=250

; Does the user want us to plot the masked regions?
if n_elements(mask) and (total(lbwsrc.mask) ne 0) then begin

	regionmasklbw, lbwsrc, regions ; Find the regions

	for i=0L, n_elements(regions)-1, 2 do begin
		oplot, [xvals[regions[i]], xvals[regions[i]]],[-1e4, 1e4], linestyle=2, color=50
		oplot, [xvals[regions[i+1]], xvals[regions[i+1]]],[-1e4, 1e4], linestyle=2, color=50
		oplot, xvals[regions[i]:regions[i+1]], spectrum[regions[i]:regions[i+1]], color=50
	endfor

	legend, ['Spectrum','Baselined Region'], charsize=1.5, linestyle=[0,2], colors=[250,50], box=0
endif


; Reset the plotting details
loadct, 0, /silent
;hor
;ver

; Plot a nice horizontal line to show where 0 mJy is
oplot, [xmin, xmax], [0,0], linestyle=2

END
