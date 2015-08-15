/*
**	Case Study Financial Econometrics 4.3 
**
**  Purpose:
**  	Estimate all log-linear Real GARCH (tau_1=tau_2=0) model parameters 
**
**  Date:
**    	10/01/2015
**
**  Author:
**	  	Tamer Dilaver, Koen de Man & Sina Zolnoor
**
**	Supervisor:
**		L.F. Hoogerheide & S.J. Koopman
**
*/

#include <oxstd.h>
#include <oxdraw.h>
#include <oxprob.h>
#include <maximize.h>
#import <modelbase>
#import <simula>
#include <oxfloat.h>

static decl iB;	 					//Repeats
static decl iSIZE;					//Size of time series
static decl iSTEPS;					//#Steps to divide the size
static decl iSIMS;					//# of Zt ~ N(0,1)
static decl dALPHA;			 		//actually gamma in notes
static decl dBETA;
static decl dOMEGA;
static decl dGAMMA;					//:=h_1
static decl dXI;
static decl dSIGMA2_U;
static decl dPHI;					//denoted as \varphi in notes
static decl s_vY; 					//Simulated returns
static decl s_vX; 					//Simulated realized measure
static decl s_vDate;
static decl dOMEGA_START;
static decl dBETA_START;
static decl dGAMMA_START;
static decl dXI_START;
static decl dPHI_START;
static decl dSIGMA2_U_START;
static decl dRATIO;


/*
**  Function:	Transform (start)parameters
**
**  Input: 		vTheta [parametervalues]
**
**  Output: 	vThetaStar
*/
fTransform(const avThetaStar, const vTheta){
	avThetaStar[0]=		vTheta;
	
	avThetaStar[0][0] = vTheta[0];
	avThetaStar[0][1] = log((vTheta[2]*vTheta[4])/(1-vTheta[2]*vTheta[4] - vTheta[1]));	
	avThetaStar[0][2] = log((vTheta[1])/(1-vTheta[2]*vTheta[4] - vTheta[1]));			 	 
	avThetaStar[0][3] = vTheta[3];
	avThetaStar[0][4] = log(vTheta[4]);
	avThetaStar[0][5] = log(vTheta[5]);
	return 1;
}

/*
**  Function: 	Extract the parameters from vTheta
**
**  Input: 		adOmega, adBeta, adGamma, adXi, adPhi, adTau_1, adTau_2, adSigma2_u,  vTheta
**				0		1	     2	      3	     4	    5	    6	     7		  
**  Output: 	1 
*/
fGetPars(const adOmega, const adBeta, const adGamma, const adXi, const adPhi, const adSigma2_u, const vTheta){

	adOmega[0] 	= vTheta[0];
	adBeta[0] 	= exp(vTheta[2])/(exp(vTheta[1])+exp(vTheta[2])+1);
	adGamma[0] 	= exp(vTheta[1]-vTheta[4])/(exp(vTheta[1])+exp(vTheta[2])+1);
	adXi[0] 	= vTheta[3];
	adPhi[0] 	= exp(vTheta[4]);
	adSigma2_u[0] = exp(vTheta[5]);
	return 1;
}

/*
**  Function:	Calculates average value loglikelihood for log-linear Real GARCH (tau_1=tau_2=0) given parameter values
**
**  Input: 		vTheta [parametervalues], adFunc [adres functievalue], avScore [the score], amHessian [hessianmatrix]
**
**  Output:		1
**
*/

fLogLike_LogRealGARCH(const vTheta, const adFunc, const avScore, const amHessian){
	decl dOmega, dBeta, dGamma, dXi, dPhi, dSigma2_u;
	fGetPars(&dOmega, &dBeta, &dGamma, &dXi, &dPhi, &dSigma2_u, vTheta);

	decl dlogH = (dOmega +dGamma*dXi)/(1-dBeta-dPhi*dGamma); //initialise with unconditional expectation of log conditional variance					 											//initial condition by definition
	decl vlogEta = zeros(sizerc(s_vY), 1);

	for(decl i = 0; i < sizerc(s_vY); ++i){
			//likelihood contribution
			vlogEta[i] = 2*log(M_2PI) +dlogH + s_vY[i]^2 / exp(dlogH) + log(dSigma2_u) + (log(s_vX[i]) - dXi - dPhi*dlogH)^2/dSigma2_u;		//Gaussian

			//recursion
			dlogH = dOmega + dBeta * dlogH + dGamma * log(s_vX[i]);
	}
	
	adFunc[0] = sumc(vlogEta)/(-2*sizerc(s_vY)); 									 	//Average
	return 1;
}

/*
**  Function:	Transform parameters back
**
**  Input: 		vThetaStar
**
**  Output: 	vTheta [parametervalues]
*/

fTransformBack(const avTheta, const vThetaStar){
	avTheta[0]=		vThetaStar;
	
	avTheta[0][0] = vThetaStar[0];
	avTheta[0][1] = exp(vThetaStar[2])/(exp(vThetaStar[1])+exp(vThetaStar[2])+1);
	avTheta[0][2] = exp(vThetaStar[1]-vThetaStar[4])/(exp(vThetaStar[1])+exp(vThetaStar[2])+1);
	avTheta[0][3] = vThetaStar[3];
	avTheta[0][4] = exp(vThetaStar[4]);
	avTheta[0][5] = exp(vThetaStar[5]);
	return 1;
}

/*
**  Function:	calculate standard errors
**
**  Input: 		vThetaStar
**
**  Output: 	vStdErrors
*/

fSigmaStdError(const vThetaStar){

 		decl iN, mHessian, mHess, mJacobian, vStdErrors, vP;

		iN 			= sizerc(s_vY);
		Num2Derivative(fLogLike_LogRealGARCH, vThetaStar, &mHessian);
		NumJacobian(fTransformBack, vThetaStar, &mJacobian);	  //numerical Jacobian
		mHessian 	= mJacobian*invert(-iN*mHessian)*mJacobian';
		vStdErrors 	= sqrt(diagonal(mHessian)');

		return 	vStdErrors;
}

/*
**  Function:	calculate variance of model
**
**  Input: 		vTheta
**
**  Output: 	vH [vector with variances]
*/

fVariance(const vTheta){
	decl dOmega, dBeta, dGamma, dXi, dPhi, dSigma2, vLogH;

	fGetPars(&dOmega, &dBeta, &dGamma, &dXi, &dPhi, &dSigma2, vTheta);
	
	vLogH = zeros(sizerc(s_vY),1);
	vLogH[0] = (dOmega +dGamma*dXi)/(1-dBeta-dPhi*dGamma);	
	
	for(decl i = 1; i < sizerc(s_vY); i++){	//mixed 	
		vLogH[i] = dOmega  + dBeta*vLogH[i-1]+ dGamma*log(s_vX[i-1]);

	}		   
	
	return 	exp(vLogH);
}

/*
**  Function:	Estimate log-linear Real GARCH (tau_1=tau_2=0) parameters
**
**  Input: 		vReturns, adAlpha_hat, adBeta_hat, adOmega_hat, adGamma_hat
**
**  Output: 	vTheta [estimated parametervalues]
*/

fEstimateLogRealGARCH(const vReturns, const vRealMeasure, const adOmega_hat, const adBeta_hat, const adGamma_hat, const adXi_hat, const adPhi_hat, const adSigma2_u_hat, const avVariance){

	//initialise parameter values
	decl vTheta = zeros(6,1);
	vTheta[0] = dOMEGA_START;
	vTheta[1] = dBETA_START;
	vTheta[2] = dGAMMA_START;
	vTheta[3] = dXI_START;
	vTheta[4] = dPHI_START;
	vTheta[5] = dSIGMA2_U_START;
	decl vThetaStart = vTheta;

	//globalize returns and vectorize true pars
	s_vY = vReturns;
	s_vX = vRealMeasure;

	//transform parameters
	decl vThetaStar; 
	fTransform(&vThetaStar, vTheta);

	//Maximize the LL
	decl dFunc;
	decl iA;
	iA=MaxBFGS(fLogLike_LogRealGARCH, &vThetaStar, &dFunc, 0, TRUE);

	//Transform thetasStar back
  	fTransformBack(&vTheta, vThetaStar);

	//return pars
	adOmega_hat[0] = vTheta[0];
	adBeta_hat[0] = vTheta[1];	
	adGamma_hat[0] = vTheta[2];
	adXi_hat[0] = vTheta[3];
	adPhi_hat[0] = vTheta[4];
	adSigma2_u_hat[0] = vTheta[5];

	decl vSigmaStdError = fSigmaStdError(vThetaStar);
	decl vVariance = fVariance(vThetaStar);
	avVariance[0] = vVariance;
	
	print("\n",MaxConvergenceMsg(iA));
	println("\nFunctiewaarde likelihood eindwaardes:", dFunc);
	print("\nOptimale parameters met standaarderrors \n",
          	"%r", { "omega",  "beta",  "gamma",  "xi", "phi","sigma2_u"},
          	"%c", {"thetaStart","theta","std.error"}, vThetaStart~vTheta~vSigmaStdError);
			
	return 1;
}

/*
**  Function:	Determine Forecast
**
**  Input: 		vTheta
**
**  Output: 	vH [vector of forecasts]
*/

fForecast(const vTheta){
	decl dOmega, dBeta, dGamma, dXi, dPhi, dSigma2, vLogH;

	fGetPars(&dOmega, &dBeta, &dGamma, &dXi, &dPhi, &dSigma2, vTheta);
	
	vLogH = zeros((sizerc(s_vY)+1),1);
	vLogH[0] = (dOmega +dGamma*dXi)/(1-dBeta-dPhi*dGamma);	
	
	for(decl i = 1; i < sizerc(s_vY)+1; i++){ //mixed 	
		vLogH[i] = dOmega  + dBeta*vLogH[i-1]+ dGamma*log(s_vX[i-1]);

	}		   
	
	return 	exp(vLogH[sizerc(s_vY)]);

}

/*
**  Function:	Compute MAE
**
**  Input: 		adMAE_OC [adress of MAE], vReturns_1 [return series], vBenchmark [Benchmark], dC [ratio]
**
**  Output: 	1
*/

fMAE(const adMAE, const vReturns, const vRV, const vBenchmark, const dC){

	decl iWindow = 250;
	decl iT = sizerc(vReturns);
	decl vH_forecast = zeros(iWindow, 1);
	decl vSqrd_error = zeros(iWindow, 1);

	dOMEGA_START = 0.02;
	dBETA_START = 0.6;
	dGAMMA_START = 0.4;
	dXI_START = -0.03;
	dPHI_START = 0.8;
	dSIGMA2_U_START = 0.2;  

	for(decl j = 0; j<iWindow; j++){
		s_vY = 	vReturns[j:(iT - iWindow +j)];
		s_vX = 	vRV[j:(iT - iWindow +j)];

		//initialise parametervalues
		decl vTheta = zeros(6,1);
		vTheta[0] = dOMEGA_START;
		vTheta[1] = dBETA_START;
		vTheta[2] = dGAMMA_START;
		vTheta[3] = dXI_START;
		vTheta[4] = dPHI_START;
		vTheta[5] = dSIGMA2_U_START;
	
		//transform parameters
		decl vThetaStar; 
		fTransform(&vThetaStar, vTheta);
	
		//Maximize the LL
		decl dFunc;
		decl iA;
		iA=MaxBFGS(fLogLike_LogRealGARCH, &vThetaStar, &dFunc, 0, TRUE);
	
		//Transform thetasStar back
	  	fTransformBack(&vTheta, vThetaStar);

		dOMEGA_START = vTheta[0];
		dBETA_START = vTheta[1];
		dGAMMA_START = vTheta[2];
		dXI_START = vTheta[3];
		dPHI_START = vTheta[4];
		dSIGMA2_U_START = vTheta[5];

		vH_forecast[j] = fForecast(vThetaStar);
		vSqrd_error[j] = fabs(dC*vH_forecast[j] - dRATIO*vBenchmark[(iT - iWindow +j)]);

	}
	savemat("vAE_CC_RK_LOGLIN_RK_REALGARCH_T0.xls", vSqrd_error);
	adMAE[0] = meanc(vSqrd_error);

	return 1;

}

/*
**  Function:	Compute MSE
**
**  Input: 		adMSE_OC [adress of MAE], vReturns_1 [return series], vBenchmark [Benchmark], dC [ratio]
**
**  Output: 	1
*/

fMSE(const adMSE, const vReturns, const vRV, const vBenchmark, const dC){

	decl iWindow = 250;
	decl iT = sizerc(vReturns);
	decl vH_forecast = zeros(iWindow, 1);
	decl vSqrd_error = zeros(iWindow, 1);

	dOMEGA_START = 0.02;
	dBETA_START = 0.6;
	dGAMMA_START = 0.4;
	dXI_START = -0.03;
	dPHI_START = 0.8;
	dSIGMA2_U_START = 0.2;  

	for(decl j = 0; j<iWindow; j++){
		s_vY = 	vReturns[j:(iT - iWindow +j)];
		s_vX = 	vRV[j:(iT - iWindow +j)];

		//initialise parameter values
		decl vTheta = zeros(6,1);
		vTheta[0] = dOMEGA_START;
		vTheta[1] = dBETA_START;
		vTheta[2] = dGAMMA_START;
		vTheta[3] = dXI_START;
		vTheta[4] = dPHI_START;
		vTheta[5] = dSIGMA2_U_START;
	
		//transform parameters
		decl vThetaStar; 
		fTransform(&vThetaStar, vTheta);
	
		//Maximize the LL
		decl dFunc;
		decl iA;
		iA=MaxBFGS(fLogLike_LogRealGARCH, &vThetaStar, &dFunc, 0, TRUE);
	
		//Transform thetaStar back
	  	fTransformBack(&vTheta, vThetaStar);

		dOMEGA_START = vTheta[0];
		dBETA_START = vTheta[1];
		dGAMMA_START = vTheta[2];
		dXI_START = vTheta[3];
		dPHI_START = vTheta[4];
		dSIGMA2_U_START = vTheta[5];

		vH_forecast[j] = fForecast(vThetaStar);
		vSqrd_error[j] = (dC*vH_forecast[j] - dRATIO*vBenchmark[(iT - iWindow +j)])^2;
	}

	adMSE[0] = meanc(vSqrd_error);

	return 1;

}

/*
**	MAIN PROGRAM
**
**  Purpose:	Estimate log-linear Real GARCH (tau_1=tau_2=0) parameters
**
**  Output: 	Figures
*/

main(){
	//laad SBUX returns
	decl mData_1 = loadmat("ReturnsOpenToClose.csv");
	decl mData_2 = loadmat("ReturnsCloseToClose.csv"); 
	decl vReturns_1 = 100*mData_1[:][1];
	decl vReturns_2 = 100*mData_2[:][1];

	decl vRV = loadmat("RV.csv");
	decl vBV = loadmat("BV.csv");
	decl vRK = loadmat("RK.csv");
	
	dRATIO = (varc(vReturns_1) +varc(vReturns_2))/varc(vReturns_1);
	
	s_vX = vRK;   		//pick vRV, vBV or vKV

	//laad Dates SBUX returns
	decl vTemp_Date = mData_2[][0];
	decl vYear 		= floor(vTemp_Date/10000);							
	decl vMonth 	= floor((vTemp_Date-floor(vTemp_Date/10000)*10000)/100);	
	decl vDay 		= vTemp_Date-floor(vTemp_Date/100)*100;
	s_vDate 		= dayofcalendar(vYear, vMonth, vDay);

	dOMEGA_START = 0.02;
	dBETA_START = 0.6;
	dGAMMA_START = 0.4;
	dXI_START = -0.03;
	dPHI_START = 0.8;
	dSIGMA2_U_START = 0.2; 
	
	decl dOmega_hat, dBeta_hat, dGamma_hat, dXi_hat, dPhi_hat, dSigma2_u_hat;
	decl vVariance_1, vVariance_2;
	print("\nO-C");
	fEstimateLogRealGARCH(vReturns_1, s_vX, &dOmega_hat, &dBeta_hat, &dGamma_hat, &dXi_hat, &dPhi_hat, &dSigma2_u_hat, &vVariance_1);

	print("\nC-C");
	fEstimateLogRealGARCH(vReturns_2, s_vX, &dOmega_hat, &dBeta_hat, &dGamma_hat, &dXi_hat, &dPhi_hat, &dSigma2_u_hat, &vVariance_2);

	//graphs
	SetDrawWindow("CS_EMP_6_log-linear_RealGARCH(1,1)");
	DrawTMatrix(0, (vReturns_1~sqrt(vVariance_1))', {"Open-to-close"}, s_vDate');
	DrawTMatrix(1, (vReturns_2~sqrt(vVariance_2))', {"Close-to-close"}, s_vDate');
	ShowDrawWindow();

	//forecasts MAE	and MSE
	decl vBenchmark = vRK;
	decl dMAE_OC;
	fMAE(&dMAE_OC, vReturns_1, vRK, vBenchmark, dRATIO);
	print("\n dMAE_OC = ",dMAE_OC);
	
	decl dMAE_CC;
	fMAE(&dMAE_CC, vReturns_2, vRK, vBenchmark, 1);
	print("\n dMAE_CC = ",dMAE_CC);

	decl dMSE_OC;
	fMSE(&dMSE_OC, vReturns_1, vRK, vBenchmark, dRATIO);
	print("\n dMSE_OC = ",dMSE_OC);
	
	decl dMSE_CC;
	fMSE(&dMSE_CC, vReturns_2, vRK, vBenchmark, 1);
	print("\n dMSE_CC = ",dMSE_CC);
}
