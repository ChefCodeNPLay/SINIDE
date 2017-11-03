using System.Web;
using System.Web.Mvc;

namespace SinideV2_0_Sitio
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            filters.Add(new HandleErrorAttribute());
        }
    }
}
