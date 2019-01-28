;NAME:
;	
;	lbwrecallplot - plots the spectrum of a saved lbwsrc structure
;
;SYNTAX:
;
;	lbwrecallplot, filename, raw=raw, measure=measure, freq=freq, mask=mask
;
;ARGS:
;
;	filename - .sav file containing data of an LBW reduced spectrum
;
;OPTIONAL KEYWORDS:
;
;	raw - plots raw, unbaselined spectrum
;	measure - plots baselined spectrum with 2-horn or gaussian fit
;	freq - plots spectrum in frequency space
;	mask - plots baselined spectrum with masks
;
;DESCRIPTION:
;	
;	User inputs the name of a .sav file containing an LBW reduced spectrum 
;	lbwrecallplot restores the structure recorded in the file and reconstructs
;	a plot of the fitted/measured spectrum 
;	NB: the plot produced will not be interactive. lbwrecallplot only allows
;	the user to view the final product of the baseline fitting and source
;	measurement
;
;HISTORY:
;
;	AF 		23Jun2014		Original Version


PRO lbwrecallplot, filename, raw=raw, measure=measure, freq=freq, mask=mask

;RESTORE FILE SO THAT DATA STRUCTURE CAN BE ACCESSED

	restore, filename

;CHECK FOR VALID COMBINATION OF KEYWORDS

	if keyword_set(mask) then begin
		if keyword_set(raw) then begin
			print, 'Invalid input. Cannot plot both raw and masked spectrum.'
			stop
		endif 
	endif
	if keyword_set(measure) then begin
		if keyword_set(raw) then begin
			print, 'Invalid input. Cannot plot both raw and measured spectrum.'
			stop		
		endif
		if keyword_set(freq) then begin
			print, 'Invalid input. Cannot plot measured spectrum in frequency space.'
			stop
		endif
	endif

;PLOT SPECTRUM ACCORDING TO KEYWORD SPECIFICATIONS

	if keyword_set(freq) then begin

		if keyword_set(raw) then begin

		;Plot raw spectrum in frequency space
		;This part is mostly lifted straight from lbwplot, but modified to use
		;the raw spectrum

			xvals=lbwsrc.freq
			yvals=lbwsrc.raw

			xmin = min(xvals)
			xmax = max(xvals)

			tempspec=lbwsrc.raw
			if (where(lbwsrc.mask))[0] ne -1 then begin
				maskleft = min(where(lbwsrc.mask))
				maskright = max(where(lbwsrc.mask))
				tmpspec = lbwsrc.raw[maskleft:maskright]
			endif

		    rangey = max(tempspec)-min(tempspec) 
			ymin = min(tempspec)-0.05*rangey
			ymax = max(tempspec)+0.05*rangey

			hor, xmin, xmax
			ver, ymin, ymax

			loadct, 0, /silent
			plot, [0,0],[0,0], /nodata, $
 			xtitle='Frequency (MHz)', ytitle='Flux Density (mJy)', $
  			title = lbwsrc.LBWsrcname, $
  			charsize=1.5

			loadct, 13, /silent			
			oplot, xvals, yvals, color=250

			loadct, 0, /silent
			oplot, [xmin, xmax], [0,0], linestyle=2

		endif else if keyword_set(mask) then begin

			;Plot masked spectrum in frequency space

			lbwplot, lbwsrc, /freq, /mask
		
		endif else begin
	
			;Plot plain old spectrum in frequency space	

			lbwplot, lbwsrc, /freq

		endelse

	endif else if keyword_set(measure) then begin

		;Plot measured spectrum

		;If the source was not actually measured, simply plot masked spectrum
	
		if lbwsrc.fittype eq '' then begin
			lbwplot, lbwsrc, /mask
			print, 'Source was not measured. Plotting baselined spectrum with masks.'
		
		;If the source was measured with a 2-horn fit, reproduce this fit
		;This part is mostly borrowed from lbwmeasure
	
		endif else if lbwsrc.fittype eq 'P' then begin
			lbwplot, lbwsrc, /mask, xrange=[lbwsrc.vel[lbwsrc.nchan/2-251], lbwsrc.vel[lbwsrc.nchan/2+249]]
		
			fitedge=lbwsrc.fitedge[sort(lbwsrc.fitedge)]
	
			loadct, 13, /silent
	
			edge=[fitedge[0], fitedge[1]]
			edgefit, lbwsrc, edge, leftfit, flag, markup=markup
			oplot, lbwsrc.vel, leftfit.coef[0]+leftfit.coef[1]*lbwsrc.vel, color=225, thick=2

			edge=[fitedge[2], fitedge[3]]
			edgefit, lbwsrc, edge, rightfit, flag, /right, markup=markup
			oplot, lbwsrc.vel, rightfit.coef[0]+rightfit.coef[1]*lbwsrc.vel, color=225, thick=2
	
			oplot, [lbwsrc.vsys, lbwsrc.vsys], [-100,1e4], linestyle=2, color=150
			oplot, [leftfit.vel, rightfit.vel], 0.25*(leftfit.fp+rightfit.fp)*[1,1], linestyle=2, color=150 

			print, ''
			print, 'W50 = ', lbwsrc.W50, ' +/- ', lbwsrc.W50err,' km/s '
			print, 'W20 = ', lbwsrc.W20, ' +/- ', lbwsrc.W20err,' km/s '
			print, 'vsys = ', lbwsrc.vsys, ' +/- ', lbwsrc.Vsyserr, ' km/s'
			print, 'flux = ', lbwsrc.flux,' +/- ', lbwsrc.fluxerr, ' Jy km/s'
			print, 'SN = ', lbwsrc.SN

		;If the source was measured with a gaussian fit, reproduce this fit
		;This part also borrows heavily from lbwmeasure
	
		endif else begin
			lbwplot, lbwsrc, /mask, xrange=[lbwsrc.vel[lbwsrc.nchan/2-251], lbwsrc.vel[lbwsrc.nchan/2+249]]
			
			fitedge=lbwsrc.fitedge[sort(lbwsrc.fitedge)]

			deltaedge = lbwsrc.vel[fitedge[0]]-lbwsrc.vel[fitedge[1]]
			midpt = lbwsrc.vel[edge[1]]+deltaedge/2.
			area = lbwsrc.spec[closest(lbwsrc.vel,midpt)]*deltaedge
			start = [0.D, midpt, 0.67*deltaedge, area]
			YERR = lbwsrc.rms
			Smask = lbwsrc.mask
			Smask[fitedge[0]:fitedge[1]] = 1
			Svel  = lbwsrc.vel[where(smask)]
			Sspec = lbwsrc.spec[where(smask)]
			result = MPFITFUN('MYGAUSS', Svel, Sspec, YERR, start, /quiet, covar=COV)
	
			oplot, lbwsrc.vel, result(0)+gauss1(lbwsrc.vel, result(1:3)), color=225, thick=2

		endelse
		
	endif else if keyword_set(mask) then begin

		;Plot masked spectrum

		lbwplot, lbwsrc, /mask

	endif else if keyword_set(raw) then begin

		;Plot raw spectrum in velocity space
		;Again, this part modified from lbwplot to use raw spectrum

		xvals=lbwsrc.vel			
		yvals=lbwsrc.raw

		xmin = min(xvals)
		xmax = max(xvals)

		tempspec=lbwsrc.raw
		if (where(lbwsrc.mask))[0] ne -1 then begin
			maskleft = min(where(lbwsrc.mask))
			maskright = max(where(lbwsrc.mask))
			tmpspec = lbwsrc.raw[maskleft:maskright]
		endif

	    rangey = max(tempspec)-min(tempspec) 
		ymin = min(tempspec)-0.05*rangey
		ymax = max(tempspec)+0.05*rangey

		hor, xmin, xmax
		ver, ymin, ymax

		loadct, 0, /silent
		plot, [0,0],[0,0], /nodata, $
		xtitle=textoidl('Velocity (km s^{-1})'), ytitle='Flux Density (mJy)', $
		title = lbwsrc.LBWsrcname, $
		charsize=1.5

		loadct, 13, /silent			
		oplot, xvals, yvals, color=250

		loadct, 0, /silent		
		oplot, [xmin, xmax], [0,0], linestyle=2

	endif else begin
	
		;Plot plain old spectrum in plain old velocity space
	
		lbwplot, lbwsrc

	endelse

;ASK USER FOR COMMENTS

print
print, 'Please enter any further comments:'
response=''
read, response
if response ne '' then lbwcomments, lbwsrc, response, /add
save, lbwsrc, filename=lbwsrc.LBWsrcname+'.sav'

print
print, 'Plot recall complete!'

END
