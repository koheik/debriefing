package com.koheik;

import com.garmin.fit.*;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.PrintWriter;

import java.nio.file.FileSystems;
import java.nio.file.Path;

import java.awt.event.*;
import java.awt.Container;
import java.awt.Component;
import javax.swing.*;

public class FitExtractor implements Runnable, ActionListener {
    

    public static void main( String[] args ) {

        if (args.length > 0) {
            File file = new File(args[0]);
            FitExtractor fe = new FitExtractor();
            fe.decode(file);
        } else {
            javax.swing.SwingUtilities.invokeLater(new FitExtractor());
        }
    }

    private void createMainWindow() {
        JFrame frame = new JFrame("FitExtractor");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(200, 200);

        Container pane = frame.getContentPane();
        pane.setLayout(new BoxLayout(pane, BoxLayout.Y_AXIS));

        JLabel label = new JLabel("Convert .FIT to .gpsmeta etc.");
        label.setAlignmentX(Component.CENTER_ALIGNMENT);
        pane.add(label);

        JButton b1 = new JButton("Open");
        b1.setAlignmentX(Component.CENTER_ALIGNMENT);
        b1.setActionCommand("open");
        b1.addActionListener(this);
        pane.add(b1);

        JButton b2 = new JButton("Done");
        b2.setAlignmentX(Component.CENTER_ALIGNMENT);
        b2.setActionCommand("done");
        b2.addActionListener(this);
        pane.add(b2);

        frame.pack();
        frame.setVisible(true);
    }

    public void run() {
        createMainWindow();
    }

    public void actionPerformed(ActionEvent e) {
        if ("open".equals(e.getActionCommand())) {
            final JFileChooser fc = new JFileChooser();
            int ret = fc.showOpenDialog(null);
            if (ret == JFileChooser.APPROVE_OPTION) {
                File file = fc.getSelectedFile();
                decode(file);
            }
        } else if ("done".equals(e.getActionCommand())) {
            System.exit(0);
        }
    }

    public void decode(File file) {
        String fname = file.getAbsolutePath();

        Decode decode = new Decode();
        MesgBroadcaster mesgBroadcaster = new MesgBroadcaster(decode);
        Listener listener = new Listener();

        FileInputStream in;
        PrintWriter record;
        PrintWriter gpsmeta;
        PrintWriter camera;

        String[] tokens = fname.split("\\.(?=[^\\.]+$)");
        String dir = tokens[0];
        tokens = dir.split("/");
        String base = tokens[tokens.length - 1];

        Path path = FileSystems.getDefault().getPath(file.getParentFile().getParentFile().getAbsolutePath());
        Path npath = path.normalize();
        listener.setDirectoryPath(npath);


        try {
            in = new FileInputStream(file);
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( "Error opening file " + fname);
        }

        try {
            record = new PrintWriter(base + ".record");
            listener.setRecordStream(record);
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( "Error opening record file." );
        }

        try {
            gpsmeta = new PrintWriter(base + ".gpsmeta");
            listener.setGpsmetaStream(gpsmeta);
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( "Error opening gpsmeta file." );
        }

        try {
            camera = new PrintWriter(base + ".camera");
            listener.setCameraStream(camera);
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( "Error opening camera file." );
        }

        try {
            if ( !decode.checkFileIntegrity( (InputStream) in ) ) {
                throw new RuntimeException( "FIT file integrity failed." );
            }
        } catch ( RuntimeException e ) {
            System.err.print( "Exception Checking File Integrity: " );
            System.err.println( e.getMessage() );
            System.err.println( "Trying to continue..." );
        } finally {
            try {
                in.close();
            } catch ( java.io.IOException e ) {
                throw new RuntimeException( e );
            }
        }

        try {
            in = new FileInputStream(fname);
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( "Error opening file " + fname);
        }

        mesgBroadcaster.addListener((FileIdMesgListener) listener);
        mesgBroadcaster.addListener((UserProfileMesgListener) listener);
        mesgBroadcaster.addListener((DeviceInfoMesgListener) listener);
        mesgBroadcaster.addListener((MonitoringMesgListener) listener);
        mesgBroadcaster.addListener((RecordMesgListener) listener);

        mesgBroadcaster.addListener((GpsMetadataMesgListener) listener );
        mesgBroadcaster.addListener((CameraEventMesgListener) listener);
        mesgBroadcaster.addListener((MagnetometerDataMesgListener) listener);
        mesgBroadcaster.addListener((GyroscopeDataMesgListener) listener);

        decode.addListener((DeveloperFieldDescriptionListener) listener);

        try {
            decode.read(in, mesgBroadcaster, mesgBroadcaster);
        } catch ( FitRuntimeException e ) {
            if ( decode.getInvalidFileDataSize() ) {
                decode.nextFile();
                decode.read( in, mesgBroadcaster, mesgBroadcaster );
            } else {
                System.err.print( "Exception decoding file: " );
                System.err.println( e.getMessage() );

                try {
                    in.close();
                } catch ( java.io.IOException f ) {
                    throw new RuntimeException( f );
                }

                return;
            }
        }

        try {
            record.close();
            gpsmeta.close();
            camera.close();
            in.close();
        } catch ( java.io.IOException e ) {
            throw new RuntimeException( e );
        }
    }

    private static class Listener implements
        FileIdMesgListener,
        UserProfileMesgListener,
        DeviceInfoMesgListener,
        MonitoringMesgListener,
        RecordMesgListener,
        GpsMetadataMesgListener,
        CameraEventMesgListener,
        MagnetometerDataMesgListener,
        GyroscopeDataMesgListener,
        DeveloperFieldDescriptionListener
     {

        private Path path;

        public boolean debug = false;

        private String serialNumber;
        private PrintWriter record = null;
        private PrintWriter gpsmeta = null;
        private PrintWriter camera = null;

        public void setDirectoryPath(Path path) {
            this.path = path;
        }

        public void setRecordStream(PrintWriter out) {
            this.record = out;
        }

        public void setGpsmetaStream(PrintWriter out) {
            this.gpsmeta = out;
        }

        public void setCameraStream(PrintWriter out) {
            this.camera = out;
        }

        @Override
        public void onMesg( FileIdMesg mesg ) {
            if (this.debug) {
                System.out.println( "File ID:" );

                if ( mesg.getType() != null ) {
                    System.out.print( "   Type: " );
                    System.out.println( mesg.getType().getValue() );
                }

                if ( mesg.getManufacturer() != null ) {
                    System.out.print( "   Manufacturer: " );
                    System.out.println( mesg.getManufacturer() );
                }

                if ( mesg.getProduct() != null ) {
                    System.out.print( "   Product: " );
                    System.out.println( mesg.getProduct() );
                }

                if ( mesg.getSerialNumber() != null ) {
                    System.out.print( "   Serial Number: " );
                    System.out.println( mesg.getSerialNumber() );

                    this.serialNumber = mesg.getSerialNumber().toString();
                }

                if ( mesg.getNumber() != null ) {
                    System.out.print( "   Number: " );
                    System.out.println( mesg.getNumber() );
                }

                if ( mesg.getProductName() != null ) {
                    System.out.print( "   ProductName: " );
                    System.out.println( mesg.getProductName() );
                }
            }
        }

        @Override
        public void onMesg( UserProfileMesg mesg ) {
            System.out.println( "User profile:" );

            if ( ( mesg.getFriendlyName() != null ) ) {
                System.out.print( "   Friendly Name: " );
                System.out.println( mesg.getFriendlyName() );
            }

            if ( mesg.getGender() != null ) {
                if ( mesg.getGender() == Gender.MALE ) {
                    System.out.println( "   Gender: Male" );
                } else if ( mesg.getGender() == Gender.FEMALE ) {
                    System.out.println( "   Gender: Female" );
                }
            }

            if ( mesg.getAge() != null ) {
                System.out.print( "   Age [years]: " );
                System.out.println( mesg.getAge() );
            }

            if ( mesg.getWeight() != null ) {
                System.out.print( "   Weight [kg]: " );
                System.out.println( mesg.getWeight() );
            }
        }

        @Override
        public void onMesg( DeviceInfoMesg mesg ) {
            if (this.debug) {
                System.out.println( "Device info:" );

                if ( mesg.getTimestamp() != null ) {
                    System.out.print( "   Timestamp: " );
                    System.out.println( mesg.getTimestamp() );
                }

                if ( mesg.getBatteryStatus() != null ) {
                    System.out.print( "   Battery status: " );

                    switch ( mesg.getBatteryStatus() ) {

                    case BatteryStatus.CRITICAL:
                        System.out.println( "Critical" );
                        break;
                    case BatteryStatus.GOOD:
                        System.out.println( "Good" );
                        break;
                    case BatteryStatus.LOW:
                        System.out.println( "Low" );
                        break;
                    case BatteryStatus.NEW:
                        System.out.println( "New" );
                        break;
                    case BatteryStatus.OK:
                        System.out.println( "OK" );
                        break;
                    default:
                        System.out.println( "Invalid" );
                    }
                }
            }
        }

        @Override
        public void onMesg(MonitoringMesg mesg) {
            if (this.debug) {
                System.out.println( "Monitoring:" );

                if ( mesg.getTimestamp() != null ) {
                    System.out.print( "   Timestamp: " );
                    System.out.println( mesg.getTimestamp() );
                }

                if ( mesg.getActivityType() != null ) {
                    System.out.print( "   Activity Type: " );
                    System.out.println( mesg.getActivityType() );
                }

                // Depending on the ActivityType, there may be Steps, Strokes, or Cycles present in the file
                if ( mesg.getSteps() != null ) {
                    System.out.print( "   Steps: " );
                    System.out.println( mesg.getSteps() );
                } else if ( mesg.getStrokes() != null ) {
                    System.out.print( "   Strokes: " );
                    System.out.println( mesg.getStrokes() );
                } else if ( mesg.getCycles() != null ) {
                    System.out.print( "   Cycles: " );
                    System.out.println( mesg.getCycles() );
                }

                printDeveloperData( mesg );
            }
        }

        @Override
        public void onMesg( RecordMesg mesg ) {
            if (this.debug) {
                System.out.println( "Record:" );

                printValues(mesg, RecordMesg.HeartRateFieldNum);
                printValues(mesg, RecordMesg.CadenceFieldNum);
                printValues(mesg, RecordMesg.DistanceFieldNum);
                printValues(mesg, RecordMesg.SpeedFieldNum);

                printValues(mesg, RecordMesg.TimestampFieldNum);
                printValues(mesg, RecordMesg.PositionLatFieldNum);
                printValues(mesg, RecordMesg.PositionLongFieldNum);
                printValues(mesg, RecordMesg.CompressedSpeedDistanceFieldNum);
                printValues(mesg, RecordMesg.EnhancedSpeedFieldNum);

                printDeveloperData( mesg );
            }


            if (mesg.getTimestamp() == null
                || mesg.getPositionLat() == null
                || mesg.getPositionLong() == null
                || mesg.getEnhancedSpeed() == null) {
                return;
            }

            String str = this.serialNumber;

            str += "," + (mesg.getTimestamp().getTimestamp() + DateTime.OFFSET / 1000);
            str += "," + (mesg.getPositionLat() * 180.0 / Math.pow(2, 31));
            str += "," + (mesg.getPositionLong() * 180.0 / Math.pow(2, 31));
            str += "," + (mesg.getEnhancedSpeed() * 3600.0 / 1852);

            this.record.println(str);
        }

        private void printDeveloperData( Mesg mesg ) {
            if (this.debug) {
                for ( DeveloperField field : mesg.getDeveloperFields() ) {
                    if ( field.getNumValues() < 1 ) {
                        continue;
                    }

                    if ( field.isDefined() ) {
                        System.out.print( "   " + field.getName() );

                        if ( field.getUnits() != null ) {
                            System.out.print( " [" + field.getUnits() + "]" );
                        }

                        System.out.print( ": " );
                    } else {
                        System.out.print( "   Undefined Field: " );
                    }

                    System.out.print( field.getValue( 0 ) );
                    for ( int i = 1; i < field.getNumValues(); i++ ) {
                        System.out.print( "," + field.getValue( i ) );
                    }

                    System.out.println();
                }
            }
        }

        @Override
        public void onDescription( DeveloperFieldDescription desc ) {
            System.out.println( "New Developer Field Description" );
            System.out.println( "   App Id: " + desc.getApplicationId() );
            System.out.println( "   App Version: " + desc.getApplicationVersion() );
            System.out.println( "   Field Num: " + desc.getFieldDefinitionNumber() );
        }

        private void printValues( Mesg mesg, int fieldNum ) {
            Iterable<FieldBase> fields = mesg.getOverrideField( (short) fieldNum );
            Field profileField = Factory.createField( mesg.getNum(), fieldNum );
            boolean namePrinted = false;

            if ( profileField == null ) {
                return;
            }

            for ( FieldBase field : fields ) {
                if ( !namePrinted ) {
                    System.out.println( "   " + profileField.getName() + ":" );
                    namePrinted = true;
                }

                if ( field instanceof Field ) {
                    System.out.println( "      native: " + field.getValue() );
                } else {
                    System.out.println( "      override: " + field.getValue() );
                }
            }
        }

        @Override
        public void onMesg(CameraEventMesg mesg) {
            if (this.debug) {
                System.out.println( "CameraEvent:" );

                System.out.print( "   getTimestamp: " );
                System.out.println( mesg.getTimestamp().getTimestamp() );
                System.out.print( "   getTimestampMs: " );
                System.out.println( mesg.getTimestampMs() );
                System.out.print( "   getCameraEventType: " );
                System.out.println( mesg.getCameraEventType() );
                System.out.print( "   getCameraFileUuid: " );
                System.out.println( mesg.getCameraFileUuid() );
            }

            String[] tokens = mesg.getCameraEventType().toString().split("_");
            String ext = "MP4";
            if (tokens[1].equals("SECOND")) {
                ext = "GLV";
            }

            String uuid = mesg.getCameraFileUuid();
            tokens = uuid.split("_");
            int num1 = Integer.parseInt(tokens[7]);
            int num2 = Integer.parseInt(tokens[8]);
            String fname;
            String dir = this.path.toString() + "/DCIM/100_VIRB/";
            if (num1 == 1) {
                fname = String.format("%sVIRB%04d.%s", dir, num2, ext);
            } else {
                fname = String.format("%sVIRB%04d-%d.%s", dir, num2, num1, ext);
            }
            this.camera.println(
                tokens[5]
                + ","
                + mesg.getTimestamp().getTimestamp()
                + "."
                + mesg.getTimestampMs()
                + ","
                + fname
                + ","
                + mesg.getCameraEventType()
                + ","
                + mesg.getCameraFileUuid()
                + ","
                + tokens[7]
                + ","
                + tokens[8]
            );
        }

        @Override
        public void onMesg(MagnetometerDataMesg mesg) {
            if (this.debug) {
                System.out.println( "Magnetometer:" );

                System.out.print( "   getNumMagX: " );
                System.out.println( mesg.getNumMagX() );
                System.out.print( "   getNumMagY: " );
                System.out.println( mesg.getNumMagY() );
                System.out.print( "   getNumMagZ: " );
                System.out.println( mesg.getNumMagZ() );

                System.out.print( "   getMagX: " );
                System.out.println( mesg.getMagX(0) );
                System.out.print( "   getMagY: " );
                System.out.println( mesg.getMagY(0) );
                System.out.print( "   getMagZ: " );
                System.out.println( mesg.getMagZ(0) );
            }
        }

        @Override
        public void onMesg(GyroscopeDataMesg mesg) {
            if (this.debug) {
                System.out.println( "Gyroscope:" );

                System.out.print( "   getNumGyroX: " );
                System.out.println( mesg.getNumGyroX() );
                System.out.print( "   getNumGyroY: " );
                System.out.println( mesg.getNumGyroY() );
                System.out.print( "   getNumGyroZ: " );
                System.out.println( mesg.getNumGyroZ() );

                System.out.print( "   getCalibratedGyroX: " );
                System.out.println( mesg.getCalibratedGyroX(0) );
                System.out.print( "   getCalibratedGyroY: " );
                System.out.println( mesg.getCalibratedGyroY(0) );
                System.out.print( "   getCalibratedGyroZ: " );
                System.out.println( mesg.getCalibratedGyroZ(0) );
            }
        }

        @Override
        public void onMesg(GpsMetadataMesg mesg) {
            if (this.debug) {
                System.out.println( "GpsMetadata:" );

                System.out.print("   getTimestamp: " );
                System.out.println( mesg.getTimestamp().getTimestamp());
                System.out.print("   getTimestampMs: " );
                System.out.println( mesg.getTimestampMs() );
                System.out.print("   getPositionLat: " );
                System.out.println( mesg.getPositionLat() );
                System.out.print("   getPositionLong: " );
                System.out.println( mesg.getPositionLong() );
                System.out.print("   getEnhancedAltitude: " );
                System.out.println( mesg.getEnhancedAltitude() );
                System.out.print("   getEnhancedSpeed: " );
                System.out.println( mesg.getEnhancedSpeed() );
                System.out.print("   getHeading: " );
                System.out.println( mesg.getHeading() );
                System.out.print("   getUtcTimestamp: " );
                System.out.println( mesg.getUtcTimestamp() );

                System.out.print( "   getVelocity: " );
                for (int i = 0; i < mesg.getNumVelocity(); i++) {
                    if (i != 0) {
                        System.out.print(' ');
                    }
                    System.out.print( mesg.getVelocity(i));
                }
                System.out.println("");

                System.out.print( "   getNumVelocity: " );
                System.out.println( mesg.getNumVelocity() );
            }

            this.gpsmeta.println(
                this.serialNumber
                + ","
                + mesg.getTimestamp().getTimestamp()
                + "."
                + mesg.getTimestampMs()
                + ","
                + (mesg.getUtcTimestamp().getTimestamp() + DateTime.OFFSET / 1000)
                + ","
                // + mesg.getUtcTimestamp().getFractionalTimestamp()
                // + ","
                + (mesg.getPositionLat() * 180.0 / Math.pow(2, 31))
                + ","
                + (mesg.getPositionLong() * 180.0 / Math.pow(2, 31))
                + ","
                + (mesg.getEnhancedSpeed() * 3600.0 / 1852)
                + ","
                + mesg.getHeading()
            );
        }
    }
}
