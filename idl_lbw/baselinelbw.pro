;+
;NAME:
;baselinelbw - interactively baseline an LBW spectrum
;SYNTAX: baselinelbw, lbwsrc
;ARGS:
;       lbwsrc : the LBW spectrum structure
;DESCRIPTION:
;  Open an LBW spectrum for baselining
;  First asks user to select emission/RFI-free regions
;  Then interactively fits polynomials of different orders
; 
;HISTORY:
;
;  GH:   Jan13    Original version
;  GH: 02Jan14    Merged with masking routines
;-

PRO lbwmask, lbwsrc

TRUE  = 1
FALSE = 0

; Has the user already masked the spectrum? Then remove the previous mask, and reset downstream variables
if total(lbwsrc.mask) ne 0 then lbwreset, lbwsrc, /mask
	
;; PRELIMINARY PLOT + RESCALING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lbwsrc.yrange = [-999,-999] ; Reset the "default" zoom of the spectrum
scaleplotlbw, lbwsrc       ; Have the user interactively scale the map to desired zoom level

;; INTERACTIVE MASKING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

still_masking = TRUE
while still_masking do begin

	plotlbw, lbwsrc, yrange=yrange

	; Give the user some instructions
	print
	print, 'Mark the region(s) without the source or RFI.'
	print, 'Baseline fitting will be performed in these regions.'
	print
	print, '  Left-click to add region boundary'
	print, '  Right-click to finish adding regions.'

	; Define variables for which mouse button was clicked
	LEFT   = 1
	MIDDLE = 2
	RIGHT  = 4

	regions = 0         ; Start with an empty region list

	; Allow the user to add some regions
	adding_regions = TRUE
	while adding_regions do begin
		cursor, x, y, /up, /data
		button = !mouse.button
	
		; What kind of click was it?
		if (button and LEFT) ne 0 then begin                ; Left-clicking: add a region
			totheleft = where(lbwsrc.vel gt x)        ; Find the channel corresponding to this velocity
			chan = totheleft[n_elements(totheleft)-1]
			regions = [regions, chan]                  ; Append new channel mark

			; Make a nice line to show where this is
			loadct, 13, /silent
			oplot, [x,x],[-1e4,1e4], linestyle=2, color=50
			loadct, 0, /silent
		endif else if (button and RIGHT) ne 0 then $        ; Right-clicking: we're done here
			break
	
	endwhile
	
	regions = regions[1:n_elements(regions)-1] ; Get rid of the superfluous 0 in the first entry
	regions = regions[sort(regions)]           ; Put them in ascending order
	if n_elements(regions) mod 2 ne 0 then $   ; There need to be an EVEN number of region boundaries!
	  regions = regions[0:n_elements(regions)-2]
	
	; Add overlay of masked regions
	loadct, 13, /silent
	for i=0L, n_elements(regions)-1, 2 do begin
		oplot, lbwsrc.vel[regions[i]:regions[i+1]], lbwsrc.spec[regions[i]:regions[i+1]], color=50
	endfor
	loadct, 0, /silent

	; Ask user for confirmation
	print
	print, 'Colored regions are masked.'
	print, 'There should be no emission or RFI in the masked regions.'
	print
	print, '  Do you accept these masks? [Y/n]'
	
	response = ''
	read, response
	if strlowcase(strmid(response,0,1)) ne 'n' then break   ; Okay, we're done here!

endwhile

;; CONSTRUCT THE MASK ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lbwsrc.mask = intarr(lbwsrc.nchan)  ; Default mask "Include nothing!"
for i=0L, n_elements(regions)-1, 2 do lbwsrc.mask[regions[i]:regions[i+1]] = TRUE

END

PRO fitpolylbw, lbwsrc, order, p=p, rms=rms, yfit=yfit, coeff=coeff

	vel  = lbwsrc.vel[where(lbwsrc.mask)]   ; Get masked velocity range
	spec = lbwsrc.spec[where(lbwsrc.mask)]  ; Get masked spectrum
	N    = n_elements(vel)                    ; How many points are being fit to?

	if order ne 0 then begin
		coeff = poly_fit(vel, spec, order, sigma=sigma)
		t = coeff[order] / sigma[order]   ; t-test statistic = x/sigma
		dof = N - (order+1) - 1           ; Degrees of freedom
		p = 2 * t_pdf(-abs(t), dof)       ; p-value

		; Produce the fitted y values
		yfit = poly(lbwsrc.vel,coeff)
;		yfit = dblarr(lbwsrc.nchan)
;		for i=0L, order do begin
;			yfit += coeff[i]*lbwsrc.vel^i
;		endfor

		; Calculate the rms
		rms = stdev( spec - yfit[where(lbwsrc.mask)] )

	endif else begin
		coeff = mean(spec)                  ; coefficients
		yfit = dblarr(lbwsrc.nchan)+coeff  ; fitted y value
		rms = stdev(spec)                   ; spectral rms

		t = mean(spec)/ ( rms / N )         ; t-test statistic
		dof = N - 1 - 1                     ; Degrees of freedom
		p = 2 * t_pdf(-abs(t), dof)         ; p-value
	endelse

END

PRO baselinelbw, lbwsrc

; First, have user mask the emission
lbwmask, lbwsrc

TRUE  = 1
FALSE = 0

; Have you already fit the baselines? We should undo that
if lbwsrc.blfit.fitflag then lbwreset, lbwsrc, /baseline

;; FIT BASELINES AND GET STATS ON THEM ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vel  = lbwsrc.vel[where(lbwsrc.mask)]   ; Get masked velocity range
spec = lbwsrc.spec[where(lbwsrc.mask)]  ; Get masked spectrum
N    = n_elements(vel)                  ; How many points are being fit to?

recommend = -1 ; Which order is recommended by the program?

omax = 9                ; Maximum order fit to produce and plot
cutoff = 0.05           ; Cutoff of automated significance
rmsval = dblarr(omax+1) ; Holds all of the RMS values
pval   = dblarr(omax+1) ; 

; Find the rms values for the spectrum at each order
; we do these in reverse so that we can plot in a smart order (lowest order on top)
for o=omax, 0L, -1 do begin

	; Get the coefficients
	fitpolylbw, lbwsrc, o, p=p, rms=rms

	rmsval[o] = rms    ; Save the RMS value for this spectrum	
	pval[o] = p        ; Save the p-value for this component

endfor

; Find the recommended order
for i=0L, omax do begin
	; Is this one non-significant? Then the order before is the recommended one
	if (recommend eq -1) and (pval[i] gt cutoff) then begin
		recommend = i - 1
		if (recommend eq -1) then recommend = 0 ; The 0th order is *always* useful.
		break
	endif
endfor
; Didn't find that any coefficients were non-significant? Then choose the maximum order
if recommend eq -1 then recommend = omax

;; PRINT FIT STATISTICS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print, 'Statistics for each fit order:'
print, ' order  rms(mJy)'
titles  = ['0th', '1st', '2nd', '3rd', '4th', '5th', '6th','7th','8th','9th']
comment = strarr(omax+1)
comment[recommend] = '*'
for i=0L, n_elements(rmsval)-1 do begin
	print, '  '+titles[i]+'   '+string(rmsval[i],format='(F7.4)')+ ' '+comment[i]
endfor

;; GET USER CHOICES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print, 'Plotting a fit of the recommended order ('+titles[recommend]+').'
print, '  Enter an order [0-'+strtrim(omax,2)+'] to plot and select.'
print, '  Press [enter] to accept.'
order = recommend

accepted = FALSE
while accepted eq FALSE do begin

	plotlbw, lbwsrc, /mask
	loadct, 13, /silent
	fitpolylbw, lbwsrc, order, yfit=yfit, coeff=coeff
	oplot, lbwsrc.vel, yfit, color=150, linestyle=2
	legend, ['Spectrum','Masked Region', 'Fitted Baseline'], $
	  charsize=1.5, linestyle=[0,2,2], colors=[250,50,150], box=0
	loadct, 0, /silent

	response=''
	read, response

	if response eq '' then break
	order = fix(response) 
	if order eq -1 then break
	print, 'Plotting a '+titles[order]+' order fit.'

endwhile

;; PRODUCE BASELINED INFORMATION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lbwsrc.baseline = yfit         ; Store the fitted values for posterity

lbwsrc.blfit.fitflag = TRUE    ; Yes, we have subtracted the baseline
lbwsrc.blfit.order = order     ; This is the order of the fit
lbwsrc.blfit.coef  = coeff     ; These are the coefficients

;; PRODUCE HANNING SMOOTHED SPECTRUM ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lbwsrc.spec = lbwsmooth(lbwsrc, 'h', rms=rms)
lbwsrc.rms = rms

print, 'RMS of Hanning smoothed spectrum: '+ string(rms)
print

; Plot the spectrum with the narrowest window
if lbwsrc.yrange[0] ne -999 then lbwsrc.yrange -= mean(lbwsrc.baseline)
print, 'Plotting baseline-subtracted spectrum...'
;scaleplotlbw, lbwsrc
plotlbw, lbwsrc

END
