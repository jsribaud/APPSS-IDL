PRO lbwreset, lbwspec, fit=fit, baseline=baseline, mask=mask

TRUE  = 1
FALSE = 0

;lbwspec.fitwidth = -1                   ; Reset the choice of smoothing to use
;lbwspec.lines = [[0,0],[0,0]]           ; Reset the lines fit to the spectral edge
;lbwspec.w50 = 0.                        ; Reset the w50 measurement
;lbwspec.vhel = 0.                       ; Reset the heliocentric systemic velocity

; Fits are reset. If that's as deep as we've gone, then we're done.
if keyword_set(fit) then return

lbwspec.baseline = fltarr(lbwspec.nchan) ; Reset fitted y values of baseline
lbwspec.blfit.fitflag = FALSE            ; Baseline subtraction has now not been done
lbwspec.blfit.order = -1                 ; Reset the indicator of polynomial order
lbwspec.blfit.coef = dblarr(10)          ; Reset the baseline coefficients

lbwspec.rms = 0.                         ; Measured rms value is now irrelevant
lbwsmooth, lbwspec, 'h'                  ; Reset the smoothed spectrum to "empty"

; Baselines are reset. If that's as deep as we've gone, then we're done.
if keyword_set(baseline) then return

lbwspec.mask = intarr(lbwspec.nchan)  ; Reset the mask to all zeros

; Mask is reset. That should be as deep as anything gets.
if keyword_set(mask) then return


END
