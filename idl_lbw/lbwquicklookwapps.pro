;+
;NAME:
;  lbwquicklookwapps - check lbw spectra taken by wapps
;SYNTAX: lbwquicklook, file=file, board=board, smooth=smooth, xrange=xrange, yrange=yrange, vel=vel, pol=pol, refresh=refresh
;ARGS:
;       file   : WAPP fits file to be opened. There are 3 options:
;
;OPTIONAL ARGUMENTS:
;       board  : Show only board X (options are 1-4), default is to show all.
;       smooth : Smooth this many channels (defaults to 3)
;		xrange : Change x axis to this range (default is entire board)
;       yrange : Change y axis to this range (default is dynamically chosen)
;KEYWORDS:
;       vel    : plot x axis in km/s instead of MHz
;	gps    : Remove any GPS RFI
;	view   : loop through the 'on' and 'off' records to check what is removed in lbwremovegps
;       pol    : Show both A and B polarizations, offset by 5 mJy
;DESCRIPTION:
;  Open a WAPP fitfile and produce a quick plot of LBW spectra of the boards.
;  Can be used to produce graphs after observation.
; 
;Examples:
;  lbwquicklook, '/share/pserverf.sda3/wappdata/wapp.20141127.a2899.0026.fits'
;
;HISTORY:
;   GH: 14Nov14      Original version, forked from lbwquicklook
;   KS: Jul15        Integrated lbwremovegps
;   GH: 25Nov15      Added polarization viewing
;   RM: 27Nov15      Added /refresh to force the file reload (useful if you read something too quickly after observing)
;   GH: 22Nov18      Fixed error when running out of logical units
;-
PRO lbwquicklookwapps, filename=file, smooth=smooth, xrange=xrange, yrange=yrange, vel=vel, board=board, gps=gps, view=view, pol=pol,refresh=refresh

; Turn flags into numbers
if not(n_elements(pol)) then pol = 0
if not(n_elements(vel)) then vel = 0
if not(n_elements(hires)) then hires = 0
if not(n_elements(refresh)) then refresh = 0

offset = 2.5

if n_elements(board) ne 0 then board = board - 1

; A common block containing the information about the previously loaded corfile
; This way a file doesn't need to be reloaded if someone wants to alter the plot
COMMON __lbw, filename, cordata, cordatagps

;; FIND THE FILENAME ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; What method is checkcor using to get a filename? Is it the one just run (passed nothing)?
if n_elements(file) eq 0 then begin
	print, 'LBWQuicklook for WAPPS requires a filename'
	return

; Is it a whole filename?
endif else begin

	if not(file_test(file)) then begin 
		print, 'File does not exist! Exiting.' & return
	endif

endelse

;; OPEN THE FILE AND RETRIEVE THE DATA STRUCTURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Is this file the same as the previous? If not, we have to open it.  Alternatively, if the /refresh flag is set, load the file regrdless of the previously loaded file.
if n_elements(filename) eq 0 || file ne filename  || keyword_set(refresh) then begin
	filename = file
	is=wasopen(filename,desc)
	
	; Produce onoff, containing the (ON-OFF)/OFF structure
	ONOFF_OK = corposonoff(desc, cordata, t, cals, bonrecs, boffrecs, /han, /scljy)
	if ONOFF_OK ne 1 then begin
		print, '(ON-OFF)/OFF failed.'
		return
	endif

	;Produce onoff with GPS RFI removed
	cordatagps = lbwremovegps(cals, bonrecs, boffrecs, view=view)
	

	; Close the WAPPS file and free the logical unit
	wasclose, desc

endif else begin

	onoff = cordata

endelse

if keyword_set(gps) then begin
	rawdata = cordatagps
endif else begin
	rawdata=cordata
endelse

; Average the records in the file
averaged_data = coravg(rawdata, pol=1-pol)

; Smooth over 3 channels
corsmo, averaged_data, smoothed, smo=n_elements(smooth) ? smooth : 3

; Internally scale the y values by 1000 (Jy -> mJy)
spectrum = smoothed
for i=0L, n_tags(spectrum)-1 do spectrum.(i).d *= 1000

;; CORRECT BOARD REST FREQUENCIES/OFFSETS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

HIrest = 1420.405751 ; MHz
for i=0L, n_tags(spectrum)-1 do begin
	spectrum.(i).h.dop.freqoffsets = spectrum.(i).h.dop.freqbcrest - HIrest
	spectrum.(i).h.dop.freqbcrest = HIrest
endfor

offsets = [spectrum.b1.h.dop.freqoffsets[0], spectrum.b2.h.dop.freqoffsets[0], spectrum.b3.h.dop.freqoffsets[0], spectrum.b4.h.dop.freqoffsets[0]]
minboard = where(offsets eq min(offsets))

;; PLOT THE WAPPSFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Has the user specified a yrange? If not, guess a decent range
if n_elements(yrange) eq 0 then begin
	; Only grab the boards we're plotting; always ignore the lowest frequency board (where there's lots of RFI)
	if n_elements(board) ne 0 then begin
		spec = spectrum.(board).d
	endif else begin
		spec = spectrum.(0).d[0]
		for i = 0L, n_tags(spectrum)-1 do begin
			if i ne minboard then spec = [spec, reform(spectrum.(i).d, n_elements(spectrum.(i).d))]
		endfor
		spec = spec[1:*]
	endelse

	; Find a good range to plot the data over
	center = median(spec) & chop = 3*stdev(spec)
	toohi = where(spec gt center+chop)  & if toohi[0] ne -1 then spec[toohi] = 0
	toolo = where(spec lt center-chop) & if toolo[0] ne -1 then spec[toolo] = 0
endif

; Set the vertical velocity scale
if n_elements(yrange) eq 2 then ver, yrange[0], yrange[1] else $
  ver, center-2*stdev(spec)-offset*pol, center+10*stdev(spec)+offset*pol

; Produce graph title -- stolen from Phil Perillat's corplot.pro
isecmidhms3,spectrum.(0).h.std.time,hour,min,sec
src=string(spectrum.(0).h.proc.srcname)
proc=string(spectrum.(0).h.proc.procname)
title=string(format='(A," ",I9," rec:",I4," tm:",i2,":",i2,":",i2," ",A)', $
  src,spectrum.(0).h.std.scanNumber,spectrum.(0).h.std.grpNum,hour,min,sec,proc)

xtitle = vel ? textoidl('Velocity (km s^{-1})') : 'Frequency (MHz)'
ytitle = 'Flux Density (mJy)'

if n_elements(board) ne 0 then begin
	loadct, 0, /silent		; Reset to B+W color table
	!p.multi = 0

	; Get the frequency information to set the x axis range
	freq = corfrq(spectrum.(board).h, retvel=vel)
	if n_elements(xrange) eq 2 then hor, xrange[0], xrange[1] else $
		hor, min(freq), max(freq)
	
	; Plot a "dummy" window with correct axes
	plot, [0,0],[0,0], xtitle=xtitle, ytitle='Flux Density (mJy)', title=title, /nodata, charsize=2.0

	; Plot all of the boards on the same axes
	loadct, 13, /silent		; Load the RAINBOW color table
	if not(pol) then begin
		oplot, corfrq(spectrum.(board).h, retvel=vel), spectrum.(board).d, color=250
	endif else begin
		oplot, corfrq(spectrum.(board).h, retvel=vel), spectrum.(board).d[*,0] - pol*offset, color=250
		oplot, corfrq(spectrum.(board).h, retvel=vel), spectrum.(board).d[*,1] + pol*offset, color=60
	endelse
	loadct, 0, /silent		; Return to the BORING color table
endif else begin
	!p.multi=[0,2,2]		; Set up a 2x2 plotting window
	loadct, 0, /silent		; Reset to B+W color table

	for i =0L, n_tags(spectrum)-1 do begin
		freq = corfrq(spectrum.(i).h, retvel=vel)
		hor, min(freq), max(freq)

		if i eq 0 or i eq 1 then xtmp='' else xtmp=xtitle
		if i eq 1 or i eq 3 then ytmp='' else ytmp=ytitle
		if i ne 0 then ttmp = '' else ttmp = title

		; Plot a "dummy" window with correct axes
		plot, [0,0],[0,0], xtitle=xtmp, ytitle=ytmp, title=ttmp, /nodata, charsize=2.0

		; Plot all of the boards on the same axes
		loadct, 13, /silent		; Load the RAINBOW color table

		if not(pol) then begin
			oplot, corfrq(spectrum.(i).h, retvel=vel), spectrum.(i).d, color=250
		endif else begin
			oplot, corfrq(spectrum.(i).h, retvel=vel), spectrum.(i).d[*,0] - pol*offset, color=250
			oplot, corfrq(spectrum.(i).h, retvel=vel), spectrum.(i).d[*,1] + pol*offset, color=60
		endelse

		loadct, 0, /silent		; Reset to B+W color table
	endfor

	!p.multi=0
endelse

; Reset the plotting axes to the defaults.
hor
ver

END
