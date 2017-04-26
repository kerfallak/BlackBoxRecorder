using BlackBox.Recorder;


namespace KKDemo
{
    [Dependency]
    public class Database
    {
        public decimal GetMilesConverter()
        {
            return 1.6M;
        }
    }
}
