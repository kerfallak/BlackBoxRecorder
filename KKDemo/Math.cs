using BlackBox.Recorder;

namespace KKDemo
{
 
    public class Math
    {
        [Recording]
        public decimal ConvertMilesToKm(int a)
        {
            var database = new Database();
            return a * database.GetMilesConverter();
        }
    }
}
