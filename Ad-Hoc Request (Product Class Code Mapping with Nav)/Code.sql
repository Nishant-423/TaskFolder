BEGIN TRY DROP TABLE #TMPProdFlown END TRY BEGIN CATCH END CATCH

SELECT DISTINCT 
	DepartureDate,
	FlightNumber,
	Sector,
	DOMINT,
	Capacity,--Product,
	ProductCode,--PaxCount,
	ProductClassCode,
	COUNT(DISTINCT PASSENGERID) AS FlownPaxCount ,  
	CAST(SUM(ISNULL(basefare,0)+ISNULL(discount,0)) AS DECIMAL(20,2)) AS DiscountedBaseFare,
	CAST(SUM(ISNULL(basefare,0)+ISNULL(discount,0))/COUNT(DISTINCT PASSENGERID) AS DECIMAL(20,2)) AS AvgFare

--INTO #TMPProdFlolwn
FROM
(

	SELECT DISTINCT
		IL.DEPARTUREDATE AS DEPARTUREDATE,
		IL.FlightNumber,
		CONCAT(IL.DEPARTURESTATION,'-',IL.ARRIVALSTATION) AS Sector,
		IIF(SEC1.[DOM-INT] = 'Dom' AND SEC2.[DOM-INT] = 'DOM','DOM','INT') AS DOMINT, 
		il.Capacity,
		CASE WHEN b.BookingPromoCode = 'STUDIS' THEN 'Student Discount'
			 WHEN b.BookingPromoCode = 'DFNSDISC' THEN 'Defence' 
			 WHEN b.BookingPromoCode = 'HCPFDISC' THEN 'HealthCare'
			 ELSE f.ProductCode
		END AS ProductCode,
		PJS.PRODUCTCLASSCODE AS ProductClassCode,
		PJL.PASSENGERID,
		CASE WHEN pjc.chargetype=0 THEN (ISNULL(cc.ConversionRate, 1) *SUM(pjc.chargeamount)) END AS basefare,
		CASE WHEN pjc.chargetype in(1,7) THEN (ISNULL(cc.ConversionRate, 1) * SUM(pjc.chargeamount))*-1 END AS discount    

	FROM

	NAVITAIRE..INVENTORYLEG IL WITH(NOLOCK)
	LEFT JOIN  NAVITAIRE..PASSENGERJOURNEYLEG PJL WITH(NOLOCK) ON IL.INVENTORYLEGID=PJL.INVENTORYLEGID
	LEFT JOIN  NAVITAIRE..PASSENGERJOURNEYSEGMENT PJS WITH(NOLOCK) ON PJS.PASSENGERID=PJL.PASSENGERID AND PJS.SEGMENTID=PJL.SEGMENTID
	LEFT JOIN  NAVITAIRE.ODS.PASSENGERJOURNEYCHARGE PJC WITH(NOLOCK) ON PJS.PASSENGERID=PJC.PASSENGERID AND PJC.SEGMENTID=PJs.SEGMENTID
	LEFT JOIN  NAVITAIRE..BOOKINGPASSENGER BP WITH(NOLOCK) ON BP.PASSENGERID=PJS.PASSENGERID
	LEFT JOIN  NAVITAIRE..BOOKING B WITH(NOLOCK) ON B.BOOKINGID=BP.BOOKINGID
	LEFT JOIN SGMasterData.rvm.SectorDomInt sec1 ON sec1.Sector=il.DepartureStation
	LEFT JOIN SGMasterData.rvm.SectorDomInt sec2 ON sec2.Sector=il.ArrivalStation
	LEFT JOIN NAVITAIRE.DW.CurrencyConversion CC WITH(NOLOCK) ON CAST(B.BOOKINGDATE AS DATE) =CAST(CC.CONVERSIONDATE AS DATE) AND CC.FromCurrencyCode = PJC.CURRENCYCODE AND CC.ToCurrencyCode = 'INR'              
	LEFT JOIN SGMasterData.rvm.[FareBasisproductCodes] f WITH(NOLOCK) on f.farecodes=pjs.farebasis

	WHERE 
		--FORMAT(IL.DEPARTUREDATE,'MMM-yyyy')='Apr-2024' AND 
		IL.DEPARTUREDATE = '2024-04-01' AND
		pjl.liftstatus=2

	GROUP BY 
		IL.DEPARTUREDATE ,
		IL.FlightNumber,
		CONCAT(IL.DEPARTURESTATION,'-',IL.ARRIVALSTATION) ,
		SEC1.[DOM-INT],
		SEC2.[DOM-INT],
		pjc.chargetype,
		cc.ConversionRate,
		pjl.passengerid,
		f.productcode,
		il.capacity,
		CASE WHEN b.BookingPromoCode = 'STUDIS' THEN 'Student Discount'
			 WHEN b.BookingPromoCode = 'DFNSDISC' THEN 'Defence' 
			 WHEN b.BookingPromoCode = 'HCPFDISC' THEN 'HealthCare'
			 ELSE f.ProductCode
		END,
		PJS.ProductClassCode
) a

WHERE basefare IS NOT NULL
OR discount IS NOT NULL

GROUP BY 
	DepartureDate,
	FlightNumber,
	Sector,
	DOMINT,
	Capacity,--Product,
	ProductCode,--PaxCount,
	ProductClassCode
ORDER BY DEPARTUREDATE ,FlightNumber,sector