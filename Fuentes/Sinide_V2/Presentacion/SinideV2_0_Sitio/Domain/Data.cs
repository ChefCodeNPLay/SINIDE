using SinideV2_0_Sitio.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SinideV2_0_Sitio.Domain
{
    public class Data
    {
        public IEnumerable<Navbar> navbarItems()
        {
            var menu = new List<Navbar>();
            menu.Add(new Navbar { Id = 1, nameOption = "Relevamiento anual", controller = "Home", action = "Index", imageClass = "fa fa-building-o fa-fw", status = true, isParent = true, parentId = 0});
            menu.Add(new Navbar { Id = 2, nameOption = "Indicadores de gestión educativa", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 1 });
            menu.Add(new Navbar { Id = 3, nameOption = "Por nivel", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 1 });
            menu.Add(new Navbar { Id = 4, nameOption = "Por estructura", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 1});
            menu.Add(new Navbar { Id = 5, nameOption = "Por división política-territorial", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 1 });
            menu.Add(new Navbar { Id = 6, nameOption = "Estadísticas", controller = "Home", action = "DNIEE", imageClass = "fa fa-building-o fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 4, nameOption = "Primario", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 5, nameOption = "Secundario", controller = "Home", action = "DNIEE", status = true, isParent = false, parentId = 3 });


            //menu.Add(new Navbar { Id = 3, nameOption = "Gestion Escolar", controller = "Home", action = "Index", imageClass = "fa fa-dashboard fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 4, nameOption = "Instituciones", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 5, nameOption = "Autoridades", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 6, nameOption = "Ofertas educativas", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 7, nameOption = "Cursadas", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 8, nameOption = "Alumnos", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 3 });
            //menu.Add(new Navbar { Id = 9, nameOption = "Seguimiento de políticas educativas", imageClass = "fa fa-bar-chart-o fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 10, nameOption = "Programas educativos y sociales", controller = "Home", action = "FlotCharts", status = true, isParent = false, parentId = 9 });
            //menu.Add(new Navbar { Id = 11, nameOption = "Indicadores", controller = "Home", action = "Index", imageClass = "fa fa-dashboard fa-fw", status = true, isParent = false, parentId = 0 });
            //menu.Add(new Navbar { Id = 12, nameOption = "Estadísticas", controller = "Home", action = "Index", imageClass = "fa fa-dashboard fa-fw", status = true, isParent = false, parentId = 0 });
            //menu.Add(new Navbar { Id = 13, nameOption = "Proyecciones", controller = "Home", action = "Index", imageClass = "fa fa-dashboard fa-fw", status = true, isParent = false, parentId = 0 });
            //menu.Add(new Navbar { Id = 3, nameOption = "Flot Charts", controller = "Home", action = "FlotCharts", status = true, isParent = false, parentId = 2 });
            //menu.Add(new Navbar { Id = 4, nameOption = "Morris.js Charts", controller = "Home", action = "MorrisCharts", status = true, isParent = false, parentId = 2 });
            //menu.Add(new Navbar { Id = 5, nameOption = "Tables", controller = "Home", action = "Tables", imageClass = "fa fa-table fa-fw", status = true, isParent = false, parentId = 0 });
            //menu.Add(new Navbar { Id = 6, nameOption = "Forms", controller = "Home", action = "Forms", imageClass = "fa fa-edit fa-fw", status = true, isParent = false, parentId = 0 });
            //menu.Add(new Navbar { Id = 7, nameOption = "UI Elements", imageClass = "fa fa-wrench fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 8, nameOption = "Panels and Wells", controller = "Home", action = "Panels", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 9, nameOption = "Buttons", controller = "Home", action = "Buttons", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 10, nameOption = "Notifications", controller = "Home", action = "Notifications", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 11, nameOption = "Typography", controller = "Home", action = "Typography", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 12, nameOption = "Icons", controller = "Home", action = "Icons", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 13, nameOption = "Grid", controller = "Home", action = "Grid", status = true, isParent = false, parentId = 7 });
            //menu.Add(new Navbar { Id = 14, nameOption = "Multi-Level Dropdown", imageClass = "fa fa-sitemap fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 15, nameOption = "Second Level Item", status = true, isParent = false, parentId = 14 });
            //menu.Add(new Navbar { Id = 16, nameOption = "dddddd", imageClass = "fa fa-files-o fa-fw", status = true, isParent = true, parentId = 0 });
            //menu.Add(new Navbar { Id = 17, nameOption = "Blank Page", controller = "Home", action = "Blank", status = true, isParent = false, parentId = 16 });
            //menu.Add(new Navbar { Id = 18, nameOption = "Login Page", controller = "Home", action = "Login", status = true, isParent = false, parentId = 16 });

            return menu.ToList();
        }
    }
}