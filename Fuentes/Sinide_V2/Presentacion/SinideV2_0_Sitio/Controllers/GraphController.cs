using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace SinideV2_0_Sitio.Controllers
{
    public class GraphController : Controller
    {
        // GET: Graph
        public ActionResult Index()
        {
            return View();
        }

        public ActionResult GetData()
        {
            var _data = new[] { new YAB() { y= "2010", a= 100, b= 90},
                                new YAB() { y= "2011", a= 75, b= 65},
                                new YAB() { y= "2012", a= 50, b= 40},
                                new YAB() { y= "2013", a= 75, b= 65},
                                new YAB() { y= "2014", a= 50, b= 40},
                                new YAB() { y= "2015", a= 75, b= 65},
                                new YAB() { y= "2016", a= 100, b= 90}};


            var config = new
            {
                data = _data,
                xkey = "y",
                ykeys = new[] { "a", "b" },
                labels = new[] { "Total de alumnos", "Total de Instituciones"},
                fillOpacity = 0.6,
                hideHover = "auto",
                behaveLikeLine = true,
                resize = true,
                pointFillColors = "#ffffff",
                pointStrokeColors = "black",
                lineColors = new[] { "blue", "gray" },
                element = "myfirstchart"
            };
    
            return Json(config, JsonRequestBehavior.AllowGet);
        }
        public class YAB
        {
            public string y { get; set; }
            public int a { get; set; }
            public int b { get; set; }
            public int c { get; set; }

        }

        public class Donut
        {
            public string label { get; set; }
            public int value { get; set; }
        }

        public ActionResult GetData3()
        {
            var _data = new[] { new Donut() { label = "Buenos Aires", value = 450650 },
                                new Donut() { label = "CABA", value = 201000 },
                                new Donut() { label = "Córdoba", value = 50000 },
                                new Donut() { label = "Santa Fé", value = 60000 },
                                new Donut() { label = "Corrientes", value = 20000 },
                                new Donut() { label = "Mendoza", value = 30000 },
                                new Donut() { label = "Mendoza", value = 30000 },
                                new Donut() { label = "Tucumán", value = 4000 }};


            var config = new
            {
                data = _data,
                element = "myfirstchart3",
                colors = new[] { "orange" }
            };

            return Json(config, JsonRequestBehavior.AllowGet);
        }

        public ActionResult GetData2()
        {
            var _data = new[] { new YAB() { y= "2006", a= 23000, b= 6000},
                                new YAB() { y= "2007", a= 24000, b= 7000},
                                new YAB() { y= "2008", a= 23500, b= 8000},
                                new YAB() { y= "2009", a= 25000, b= 6000},
                                new YAB() { y= "2010", a= 26000, b= 8000},
                                new YAB() { y= "2011", a= 25000, b= 6000},
                                new YAB() { y= "2012", a= 25000, b= 5000},
                                new YAB() { y= "2013", a= 25500, b= 7000},
                                new YAB() { y= "2014", a= 25600, b= 6000},
                                new YAB() { y= "2015", a= 27000, b= 5000},
                                new YAB() { y= "2016", a= 28000, b= 4000}};


            var config = new
            {
                data = _data,
                xkey = "y",
                ykeys = new[] { "a"},
                labels = new[] { "Total de Autoridades" },
                fillOpacity = 0.6,
                hideHover = "auto",
                behaveLikeLine = true,
                resize = true,
                pointFillColors = "#ffffff",
                pointStrokeColors = "black",
                lineColors = new[] { "green", "red" },
                element = "myfirstchart2"
            };

            return Json(config, JsonRequestBehavior.AllowGet);
        }

        public ActionResult GetData4()
        {
            var _data = new[] { new YAB() { y= "2006", a= 23000, b= 6000},
                                new YAB() { y= "2007", a= 24000, b= 7000},
                                new YAB() { y= "2008", a= 23500, b= 8000},
                                new YAB() { y= "2009", a= 25000, b= 6000},
                                new YAB() { y= "2010", a= 26000, b= 8000},
                                new YAB() { y= "2011", a= 25000, b= 6000},
                                new YAB() { y= "2012", a= 25000, b= 5000},
                                new YAB() { y= "2013", a= 25500, b= 7000},
                                new YAB() { y= "2014", a= 25600, b= 6000},
                                new YAB() { y= "2015", a= 27000, b= 5000},
                                new YAB() { y= "2016", a= 28000, b= 4000}};


            var config = new
            {
                data = _data,
                xkey = "y",
                ykeys = new[] { "a" },
                labels = new[] { "Total de Autoridades" },
                fillOpacity = 0.6,
                hideHover = "auto",
                behaveLikeLine = true,
                resize = true,
                pointFillColors = "#ffffff",
                pointStrokeColors = "black",
                lineColors = new[] { "green", "red" },
                element = "myfirstchart4"
            };

            return Json(config, JsonRequestBehavior.AllowGet);
        }

        public ActionResult GetData5()
        {
            var _data = new[] { new YAB() { y= "2007", a= 2666, b= 0, c= 2647},
                                new YAB() { y= "2008", a= 2778, b= 2294, c= 2441},
                                new YAB() { y= "2009", a= 4912, b= 1969, c= 2501},
                                new YAB() { y= "2010", a= 3767, b= 3597, c= 5689},
                                new YAB() { y= "2011", a= 6810, b= 1914, c= 2293},
                                new YAB() { y= "2012", a= 5670, b= 4293, c= 1881},
                                new YAB() { y= "2013", a= 4820, b= 3795, c= 1588},
                                new YAB() { y= "2014", a= 15078, b= 5967, c= 5175},
                                new YAB() { y= "2015", a= 10687, b= 4460, c= 2028},
                                new YAB() { y= "2016", a= 8432, b= 5713, c= 1791}};


            var config = new
            {
                data = _data,
                xkey = "y",
                ykeys = new[] { "a", "b", "c" },
                labels = new[] { "Total Promoción", "Total Abandono", "Total Repitencia"},
                fillOpacity = 0.6,
                hideHover = "auto",
                behaveLikeLine = true,
                resize = true,
                pointFillColors = "#ffffff",
                pointStrokeColors = "black",
                //lineColors = new[] { "green", "gray", "blue" },
                element = "myfirstchart2"
            };

            return Json(config, JsonRequestBehavior.AllowGet);
        }
    }
}