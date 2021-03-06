﻿using System.Xml.Linq;
using BlackBox.CodeGeneration;
using Moq;
using Xunit;

using BlackBox.Tests.Fakes;
using BlackBox.Recorder;

namespace BlackBox.Tests.Recorder
{
    public class SaveRecordingToDiskTest : BDD<SaveRecordingToDiskTest>
    {
        [Fact]
        public void Creates_directory_for_the_type_being_recoreded()
        {
            Given.there_is_no_directory_for_recording_on_type();
            When.we_call_the_method_beeing_recorded();
            fileMock.VerifyAll();
        }

        [Fact]
        public void Creates_directory_for_the_method_being_recorded()
        {
            Given.there_is_no_directory_for_recording_of_method();
            When.we_call_the_method_beeing_recorded();
            fileMock.VerifyAll();
        }

        [Fact]
        public void Saves_the_recording_as_XML_in_the_correct_folder()
        {
            Given.this_is_the_first_recording_of_method();
            When.we_call_the_method_beeing_recorded();
            fileMock.VerifyAll();            
        }

        [Fact]
        public void Numbers_the_recording_name_if_method_has_been_saved_before()
        {
            Given.this_is_the_second_recording_of_a_method();
            When.we_call_the_method_beeing_recorded();
            When.we_call_the_method_beeing_recorded();
            fileMock.VerifyAll();                    
        }

        private void this_is_the_second_recording_of_a_method()
        {
            there_is_no_directory_for_recording_of_method();
            fileMock.Setup(file => file.Save(It.IsAny<XDocument>(), RecordingPath2)).Verifiable();
        }

        private void this_is_the_first_recording_of_method()
        {
            there_is_no_directory_for_recording_of_method();
            fileMock.Setup(file => file.Save(It.IsAny<XDocument>(), RecordingPath)).Verifiable();
        }

        private void there_is_no_directory_for_recording_on_type()
        {            
            fileMock.Setup(file => file.DirectoryExists(TypeFolder)).Returns(false);
            fileMock.Setup(file => file.CreateDirectory(TypeFolder)).Returns("");
        }

        private void there_is_no_directory_for_recording_of_method()
        {
            fileMock.Setup(file => file.DirectoryExists(TypeFolder)).Returns(true);
            fileMock.Setup(file => file.DirectoryExists(MethodFolder)).Returns(false);
            fileMock.Setup(file => file.CreateDirectory(MethodFolder)).Returns("");
        }

        private void we_call_the_method_beeing_recorded()
        {
            simpleMath.Add(10, 10);
        }

        private const string TypeFolder = @"CharacterizationTests\BlackBox.Tests.Fakes.SimpleMath";
        private const string MethodFolder = @"CharacterizationTests\BlackBox.Tests.Fakes.SimpleMath\Add(a, b)";
        private const string RecordingPath = MethodFolder + @"\Add_a_b.xml";
        private const string RecordingPath2 = MethodFolder + @"\Add_a_b_2.xml";
   
        public SaveRecordingToDiskTest()
        {
            simpleMath = new SimpleMath();
          
            fileMock = new Mock<IFile>();
            saveRecording = new SaveRecordingToDisk(fileMock.Object, new DoNotGenerateTests());
            RecordingServices.RecordingSaver = saveRecording;
            RecordingServices.RecordingNamer = new TypeAndMethodNamer();
        }

        private readonly SaveRecordingToDisk saveRecording;        
        private readonly SimpleMath simpleMath;
        private readonly Mock<IFile> fileMock;
    }
}
