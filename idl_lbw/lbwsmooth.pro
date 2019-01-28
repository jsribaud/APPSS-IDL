;+
;NAME:
;lbwsmooth - produce a smoothed spectrum according to given window
;SYNTAX: lbwsmooth, lbwsrc, smoothtype
;ARGS:
;       lbwsrc     : the LBW spectrum structure
;       smoothtype : the type of smoothing to be applied, with the current options being
;                'h' for hanning
;                'bX' for hanning followed by boxcar width X
;DESCRIPTION:
;  Opens the lbw source structure and produces a smoothed spectrum from the "raw" one
;  The smooth spectrum is then stored in lbwsrc.smooth
; 
;HISTORY:
;
;  GH: Dec13    Original version
;
;-

PRO lbwsmooth, lbwsrc, smoothtype, spectrum, noreplace=noreplace

	; Get the spectrum to operate on.
	; If the spectrum hasn't been baselined, then lbwsrc.baseline should be all 0s
	smooth = lbwsrc.raw - lbwsrc.baseline

	; First, Hanning Smooth with a width 3 [0.25, 0.5, 0.25] window
	; If user wants another type of smoothing, this is applied to the already hanning-smoothed spectrum!
	window = [0.25, 0.5, 0.25]
	smooth = convol(smooth, window, /edge_truncate)

	method = strmid(smoothtype, 0, 1)
	; Just hanning smooth? Okay, everything's done
;	if strlowcase(method) eq 'h' then return, smooth

	; Do boxcar smoothing of specified width
	if strlowcase(method) eq 'b' then begin
		width = fix(strmid(smoothtype, 1))
		width = width + width mod 2 - 1	; Force to odd-width window

		; Produce a boxcar window and smooth
		window = dblarr(width) + 1/double(width)
		smooth = convol(smooth, window, /edge_truncate)

	endif

	; Evaluate the spectral rms
	if total(lbwsrc.mask) ne 0 then begin
		rms = stdev(smooth[where(lbwsrc.mask eq 1)])
	endif else begin
		rms = stdev(smooth)
	endelse	

	if keyword_set(noreplace) then begin
		spectrum = smooth
		return
	end

	lbwsrc.spec = smooth
	lbwsrc.rms = rms
	lbwsrc.window = smoothtype
END
