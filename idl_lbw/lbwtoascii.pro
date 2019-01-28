;+
;NAME:
;  lbwtoascii - Make a nice ASCII output of an LBW source
;SYNTAX: lbwtoascii, lbwsrc, filename=filename
;ARGS:
;OPTIONAL ARGUMENTS:
;KEYWORDS:
;
;DESCRIPTION:
; 
;HISTORY:
;
;   GH: Jan13    Original version
;   GH: Jan14    Updated version with new LBW routines, W20, etc.
;
;-

PRO lbwtoascii, lbwsrc, filename=filename

	; Did the user specify a filename? If not, use the standard format
	if n_elements(filename) eq 0 then filename = lbwsrc.LBWsrcname + '.txt'

;; OPEN THE FILE FOR WRITING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

openw, out, filename, /get_lun

;; WRITE THE HEADER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

printf, out, '#'
printf, out, '# Telescope:          Arecibo Radio Telescope'
printf, out, '# Receiver:           L-band Wide (LBW)'
printf, out, '# Source Name:        '+lbwsrc.LBWsrcname
printf, out, '# AGC Number:         '+strtrim(lbwsrc.AGC, 2)
printf, out, '# RA:                 '+string(lbwsrc.ra,  format='(F9.5)')+ ' (J2000) decimal degrees'
printf, out, '# DEC:                '+string(lbwsrc.dec, format='(F9.5)')+ ' (J2000) decimal degrees'
printf, out, '# Rest Frequency:     1420.4058 [MHz]'
printf, out, '# Channels:           '+strtrim(lbwsrc.nchan, 2)
printf, out, '# Bandwidth:          '+strtrim(fix(lbwsrc.bandwidth),2) + ' MHz'
printf, out, '#'

;; BASELINE AND RMS INFORMATION (ALSO IN HEADER ) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

printf, out, '# Mean value of continuum emission:'+strtrim(lbwsrc.continuum,2)
printf, out, '# Baseline fit order: '+strtrim(lbwsrc.blfit.order, 2)
printf, out, '# Parameters for baseline polynomial fit (A+Bx+Cx^2+...):
printf, out, '#   Order   Value [mJy / (km/s)^n]:'

for i=0L, lbwsrc.blfit.order do begin
	printf, out, '#     '+string(i,format='(I1)')+'      '+$
	  string(lbwsrc.blfit.coef[i], format='(G12.6)')
endfor
printf, out, '#'

;; SMOOTHING INFORMATION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if lbwsrc.window eq 'h' then begin
	printf, out, '# Smoothing method:          3-channel Hanning'
endif else begin
	printf, out, '# Smoothing method:          3-chan Hanning + '+strmid(lbwsrc.window,1)+' channel boxcar' 
endelse
printf, out, '# RMS for smoothed baseline: '+strtrim(lbwsrc.rms,2)+' mJy'

;; FITTED VALUE INFORMATION (ALSO IN HEADER) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if lbwsrc.flux ne 0 then begin
	printf, out, '#'
	printf, out, '# ************** FIT PARAMETERS **************'
	if lbwsrc.fittype eq 'G' then	printf, out, '# Fit Type:                Gaussian (G)'
	if lbwsrc.fittype eq 'P' then	printf, out, '# Fit Type:                Two-Horned (P)'
	printf, out, '# User Fit Boundaries:     '
	if lbwsrc.fittype eq 'G' then begin
		printf, out, '#      Lower Channel:     '+strtrim(fix(lbwsrc.fitedge[0]))
		printf, out, '#      Upper Channel:     '+strtrim(fix(lbwsrc.fitedge[1]))
	endif else begin
		printf, out, '#      Lower Left Channel:      '+strtrim(fix(lbwsrc.fitedge[0]))
		printf, out, '#      Upper Left Channel:      '+strtrim(fix(lbwsrc.fitedge[1]))
		printf, out, '#      Lower Right Channel:     '+strtrim(fix(lbwsrc.fitedge[2]))
		printf, out, '#      Upper Right Channel:     '+strtrim(fix(lbwsrc.fitedge[3]))
	endelse		
	printf, out, '# Integrated Flux Density: '+string(lbwsrc.flux, format='(F9.3)')+' +/- ' +string(lbwsrc.fluxerr, format='(F6.3)') + ' Jy km/s'
	printf, out, '# Systemic Velocity:       '+string(lbwsrc.vsys, format='(F8.2)')+'  +/- '+string(lbwsrc.vsyserr, format='(F5.2)') + '     km/s'
	printf, out, '# Velocity Width (W50):    '+string(lbwsrc.W50,  format='(F8.2)')+'  +/- '+string(lbwsrc.W50err,  format='(F5.2)') + '     km/s'
	printf, out, '# Velocity Width (W20):    '+string(lbwsrc.W20,  format='(F8.2)')+'  +/- '+string(lbwsrc.W20err,  format='(F5.2)') + '     km/s'
endif

;; USER COMMENTS (HEADER) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
printf, out, '#'
printf, out, '# Comments:'
for i=0L, lbwsrc.comments.count-1 do printf, out, '# '+lbwsrc.comments.text[i]

;; FORMAT INFORMATION (HEADER) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

printf, out, '#'
printf, out, '# Table FORMAT:   (I4,1x,F8.1,1x,F12.6,1x,F10.4,1x,F10.4,1x,F10.4,1x,F10.4)'
printf, out, '#'

printf, out, '# Column descriptions:'
printf, out, '# 1. Channel number'
printf, out, '# 2. Heliocentric Velocity (Optical Convention) [km/s]'
printf, out, '# 3. Radio frequency [MHz]'
printf, out, '# 4. Flux density of raw spectrum [mJy]'
printf, out, '# 5. Fitted baseline [mJy]'
printf, out, '# 6. Baseline-subtracted smoothed spectrum [mJy]'
printf, out, '#'
printf, out, '#######################################################'
printf, out

;baselinesubbed = lbwsrc.raw - lbwsrc.baseline

;; WRITE THE DATA CHANNEL BY CHANNEL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

for i=0L, lbwsrc.nchan-1 do begin
	printf, out, i, lbwsrc.vel[i], lbwsrc.freq[i], lbwsrc.raw[i], lbwsrc.baseline[i], lbwsrc.spec[i], $
	  format='(I4,1x,F8.1,1x,F12.6,1x,F10.4,1x,F10.4,1x,F10.4,1x,F10.4)'
endfor

;; CLOSE THE FILE AND RETURN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

close, /all, /force

END
