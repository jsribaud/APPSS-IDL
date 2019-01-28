;+
;NAME:
;  checklbw - check lbw spectra
;SYNTAX: checklbw, file, pol=pol, hires=hires
;ARGS:
;       file   : corfile to be opened. There are 3 options:
;                   leave this blank. The most recent corfile will be opened.
;                   give an integer. The corfile from the current run with that file number.
;                   give a string, the full path to the corfile
;OPTIONAL ARGUMENTS:
;       smooth : Smooth this many channels (defaults to 3)
;		xrange : Change x axis to this range (default is entire board)
;       yrange : Change y axis to this range (default is dynamically chosen)
;KEYWORDS:
;       pol    : plot both A and B polarization, offset by +/- 1.5 mJy, instead of average
;       hires  : plot high resolution boards 3+4 instead of boards 1+2
;       vel    : plot x axis in km/s instead of MHz
;DESCRIPTION:
;  Open a corfile and produce a quick plot of LBW spectra during a2707 observation.
;  Can be used to produce graphs after observation, but more in-depth.
; 
;Examples:
;  checklbw     ; Open most recent corfile. Only do this while logged in at Arecibo!
;  checklbw, 25 ; Open the most recent corfile ending in *a2707.25 Only do this while logged in at Arecibo!
;  checklbw, '/home/yourstuff/lbw/corfile.12jan16.a2707.25', /pol
;               ; Opens the corfile with the given file path, show both polarizations
;
;HISTORY:
;   Original version by Greg Hallenbeck (GH)
;   MH: 14Nov12      Changed references to a2669 to a2707
;   GH: 13Jan13      Changed to use /hires flag as well as an xrange argument
;                    Documentation updated as well
;-
PRO checklbw, filename=file, pol=pol, hires=hires, smooth=smooth, xrange=xrange, yrange=yrange, vel=vel

; Turn flags into numbers
if not(n_elements(pol)) then pol = 0
if not(n_elements(vel)) then vel = 0
if not(n_elements(hires)) then hires = 0

offset = 1.5		; +/- offset for polarizations

; A common block containing the information about the previously loaded corfile
; This way a file doesn't need to be reloaded if someone wants to alter the plot
COMMON __lbw, filename, cordata


;; FIND THE FILENAME ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; What method is checkcor using to get a filename? Is it the one just run (passed nothing)?
if n_elements(file) eq 0 then begin
	spawn, 'ls -t /share/olcor/corfile.*.a2853.*', files
	file = files[0]
	print, file

; Is it a whole filename (passed a long string)?
endif else if size(file, /tname) eq 'STRING' and strlen(file) gt 30 then begin

	if not(file_test(file)) then begin 
		print, 'File does not exist! Exiting.' & return
	endif

; Is it the file index? (passed a number)?
endif else if size(file, /tname) eq 'INT' then begin

	spawn, 'ls -t /share/olcor/corfile.*.a2853.'+strtrim(file,2), files
	file = files[0]
	print, file

	if not(file_test(file)) then begin
		print, 'File ' +filename+ ' does not exist! Exiting.'
		return
	endif

endif

;; OPEN THE FILE AND RETRIEVE THE DATA STRUCTURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Is this file the same as the previous? If not, we have to open it.
if n_elements(filename) eq 0 || file ne filename then begin
	filename = file
	openr, in, filename, /get_lun
	
	; Produce onoff, containing the (ON-OFF)/OFF structure
	ONOFF_OK = corposonoff(in, cordata, /han, /scljy)
	if ONOFF_OK ne 1 then begin
		print, '(ON-OFF)/OFF failed.'
		return
	endif

	; Close the corfile and free the logical unit
	close, in, /force 
	free_lun, in

endif else begin

	onoff = cordata

endelse

; Average the records in the file
averaged_data = coravg(cordata, pol=1-pol)

; Smooth over 3 channels
corsmo, averaged_data, smoothed, smo=n_elements(smooth) ? smooth : 3

; Internally scale the y values by 1000 (Jy -> mJy)
spectrum = smoothed
for i=0L, n_tags(spectrum)-1 do spectrum.(i).d *= 1000

;; PLOT THE CORFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Starting board. Has the following values:
; Smoothing over polarizations? Then board 1 (tag 0); if hires, board 3 (tag 1)
; Not doing so? then board 1 (tag 0); if hires, then virtual board 2 (tag 1)
board = hires * (pol + 1)

; Find a good range to plot the data over
; Based on the first board only: this has the data (if /pol is set? too bad. Still use board 1)
spec = spectrum.(board).d
if pol then spec = (spec+spectrum.(board+1).d)/2.
center = median(spec) & chop = 3*stdev(spec)
toohi = where(spec gt center+chop)  & if toohi[0] ne -1 then spec[toohi] = 0
toolo = where(spec lt center-chop) & if toolo[0] ne -1 then spec[toolo] = 0

; Set the vertical velocity scale
if n_elements(yrange) eq 2 then ver, yrange[0], yrange[1] else $
  ver, center-2*stdev(spec)-offset*pol, center+10*stdev(spec)+offset*pol

; Get the frequency information to set the x axis range
freq = corfrq(spectrum.(board).h, retvel=vel)
if n_elements(xrange) eq 2 then hor, xrange[0], xrange[1] else $
  hor, min(freq), max(freq)

; Produce graph title -- stolen from Phil Perillat's corplot.pro
isecmidhms3,spectrum.(0).h.std.time,hour,min,sec
src=string(spectrum.(0).h.proc.srcname)
proc=string(spectrum.(0).h.proc.procname)
title=string(format='(A," ",I9," rec:",I4," tm:",i2,":",i2,":",i2," ",A)', $
  src,spectrum.(0).h.std.scanNumber,spectrum.(0).h.std.grpNum,hour,min,sec,proc)

xtitle = vel ? textoidl('Velocity (km s^{-1})') : 'Frequency (MHz)'

; Plot a "dummy" window with correct axes
ytitle = pol ? 'Flux Density +/- 1.5 (mJy)' : 'Flux Density (mJy)'
plot, [0,0],[0,0], xtitle=xtitle, ytitle='Flux Density (mJy)', title=title, /nodata, charsize=2.0

; Plot all of the boards on the same axes
loadct, 13, /silent		; Load the RAINBOW color table
oplot, corfrq(spectrum.(board).h, retvel=vel), spectrum.(board).d + pol*offset, color=250
if pol then oplot, corfrq(spectrum.(board+1).h), spectrum.(board+1).d - pol*offset, color=60
loadct, 0, /silent		; Return to the BORING color table

; Reset the plotting axes to the defaults.
hor
ver

;istat = corget(lun, b)
;print, string(data.(0).h.proc.srcname)

END
