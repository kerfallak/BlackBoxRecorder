using System.Linq;
using BlackBox.Testing;
using Xunit;

namespace CharacterizationTests
{
	public partial class ConvertMilesToKm_a_Tests : CharacterizationTest
	{
		private System.Int32 aInput;
		private System.Int32 aOutput;

		private System.Decimal expected;
		private System.Decimal actual;
		private KKDemo.Math target;

		private void Run(string filename)
		{
			LoadRecording(filename);
			target = new KKDemo.Math();

			aInput = (System.Int32)GetInputParameterValue("a");
			aOutput = (System.Int32)GetOutputParameterValue("a");

			expected = (System.Decimal)GetReturnValue();
			actual = target.ConvertMilesToKm(aInput);

			ConfigureComparison(filename);
			CompareObjects(aInput, aOutput);
			CompareObjects(expected, actual);
		}

		public ConvertMilesToKm_a_Tests()
		{
			Initialize();
		}

		protected override void ConfigureComparison(string filename)
		{
			//// Use the filename of the test to setup different
			//// comparison configurations for each test.
			//if(filename.EndsWith("ConvertMilesToKm_a.xml"))
			//{
			//    // Use IgnoreOnType to exclude a property from the comparison for all objects of that type.
			//    IgnoreOnType((System.Decimal s) => s.NoPublicInstancePropertiesAvailable);
			//
			//    // Use Ignore to exclude a property from the comparison for a specific instance.
			//    Ignore(expected, (System.Decimal s) => s.NoPublicInstancePropertiesAvailable);
			//}
		}

		[Fact]
		public void ConvertMilesToKm_a()
		{
			Run(@"..\..\..\KKDemo\CharacterizationTests\KKDemo.Math\ConvertMilesToKm(a)\ConvertMilesToKm_a.xml");
		}

	}
}

