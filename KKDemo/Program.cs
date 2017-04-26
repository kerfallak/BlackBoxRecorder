using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using BlackBox;
using BlackBox.CodeGeneration;

namespace KKDemo
{
    public class Program
    {
        public static void Main(string[] args)
        {
            ConfigureBlackBox();

            var math = new Math();
            var k = math.ConvertMilesToKm(10);
            Console.WriteLine(k);
        }

        private static void ConfigureBlackBox()
        {
            Configuration.OutputDirectory = @"..\..\..\KKDemo\";
            Configuration.TestFlavour = TestFlavour.CreateXunit();
        }
    }
}
