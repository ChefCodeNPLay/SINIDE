using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace SinideV2_0_Sitio.Controllers
{
    public class HomeController : Controller
    {
        // GET: Home
        public ActionResult Index()
        {
           
            return View();
        }

        public ActionResult DNIEE()
        {
            return View("DNIEE");
        }

        public ActionResult DNIEE_Jurisdicciones()
        {
            return View("DNIEE_jurisdicciones");
        }

       public ActionResult Alumnos()
       {
            return View("Alumnos");
       }

       public ActionResult Instituciones()
       {
            return View("Instituciones");
       }
       public ActionResult OfertasEducativas()
       {
           return View("OfertaEducativa");
       }


    }
}