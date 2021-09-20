//
//  ImprintAndPrivacy.swift
//  LivePhotosCleanUp
//
//  Created by Marco Schillinger on 01.07.21.
//

import SwiftUI

struct ImprintAndPrivacy: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading) {
                Text("view_imprintPrivacy_imprint_title").font(.largeTitle)
                VStack(alignment: .leading) {
//                    Text("view_imprintPrivacy_imprint_sectionTitle_company").font(.title)
                    Text("Mathema GmbH")
                    Text("view_imprintPrivacy_imprint_leader") + Text(": Andreas Hanke, Thomas Haug")
                    Text("Schillerstraße 14")
                    Text("90409 ") + Text("view_imprintPrivacy_imprint_adress_city")
                    Text("view_imprintPrivacy_imprint_adress_country").padding(.bottom)
                    Text("view_imprintPrivacy_imprint_adressCompany") + Text(": ") + Text("view_imprintPrivacy_imprint_adress_city")
                    Text("view_imprintPrivacy_imprint_registereintrag") + Text(": HR B 35517, Nürnberg/Bayern")
                    Text("view_imprintPrivacy_imprint_umsatzsteuerNr") + Text(": DE 813 467 785")
                }

                Group {
                    Text("view_imprintPrivacy_imprint_sectionTitle_contact").font(.title)
                    HStack {
                        Text("view_imprintPrivacy_imprint_phone")
                        Link("+49 911 3767450", destination: URL(string: "tel:00499113767450")!)
                    }
                    HStack {
                        Text("view_imprintPrivacy_imprint_fax")
                        Link("+49 911 3767450", destination: URL(string: "tel:004991137674555")!)
                    }
                    HStack {
                        Text("view_imprintPrivacy_imprint_email")
                        Link("info@mathema.de", destination: URL(string: "mailto:info@mathema.de")!)
                    }
                    HStack {
                        Text("view_imprintPrivacy_imprint_website")
                        Link("www.mathema.de", destination: URL(string: "https://www.mathema.de")!)
                    }
                }

            }
            VStack(alignment: .leading) {
                Text("view_imprintPrivacy_privacy_title").font(.largeTitle)
                Text("view_imprintPrivacy_privacy_text")
            }
            Spacer()
        }.frame(maxWidth: .infinity)
        .padding()
    }
}

struct ImprintAndPrivacy_Previews: PreviewProvider {
    static var previews: some View {
        ImprintAndPrivacy()
    }
}
