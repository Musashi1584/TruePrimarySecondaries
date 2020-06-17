//-----------------------------------------------------------
//	Class:	LoadoutApiFactory
//	Author: Musashi
//	
//-----------------------------------------------------------


class LoadoutApiFactory extends Object;

static function LoadoutApiInterface GetLoadoutApi()
{
	local LoadoutApiInterface ApiInterface;
	local object CDO;
	
	CDO = class'XComEngine'.static.GetClassDefaultObjectByName('LoadoutApiLib');
	ApiInterface = LoadoutApiInterface(CDO);
	return ApiInterface;
}