using Microsoft.AspNetCore.Mvc.Rendering;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using StudentLib;

namespace DB_Team_Project_A_L_T.Models
{
    public class StudentModel
    {
        public static List<Student> AllStudents;

        int StudentID;

        [Required(ErrorMessage ="Please Enter the First Name")]
        [DisplayName("First Name")]
        string FirstName { get; set; }

        [Required(ErrorMessage = "Please Enter the Last Name")]
        [DisplayName("Last Name")]
        string LastName { get; set; }

        [DisplayName("Preferred Name")]
        string PreferredName { get; set; }

        [Required(ErrorMessage = "Please Enter the Password")]
        [DataType(DataType.Password)]
        [DisplayName("Password")]
        string Password { get; set; }

        bool IsAdmin;
    }
}
